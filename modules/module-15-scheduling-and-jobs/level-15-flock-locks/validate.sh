#!/bin/bash
# Runs a copy of sync.sh (with SYNC_SECONDS=1) from / as cron would:
#  1. six copies released at the same instant: exactly one works, the other
#     five exit non-zero within 1 s with a message;
#  2. a later single run works, and holds a kernel file lock on a file in the
#     sandbox while it runs (probed with flock -n -s on every file);
#  3. after a run is killed with kill -9, the next run still works.
SANDBOX="$(cd "$1" && pwd)"
cd "$SANDBOX" || exit 1

if [ ! -f sync.sh ]; then
  echo "❌ sync.sh is missing (type reset to get it back)"
  exit 1
fi
sum=$(sha256sum sync.sh 2>/dev/null || shasum -a 256 sync.sh)
if [ "${sum%% *}" = "$(cat .lm/orig.sha 2>/dev/null)" ]; then
  echo "❌ sync.sh is unchanged: two copies still run at the same time"
  exit 1
fi
if [ ! -x sync.sh ]; then
  echo "❌ sync.sh is not executable any more; cron runs it by its path"
  exit 1
fi
if ! grep -q 'SYNC_SECONDS' sync.sh; then
  echo "❌ sync.sh no longer uses SYNC_SECONDS for the sync time; keep that line so it can be tested"
  exit 1
fi
for pid in $(pgrep -f 'sync\.sh' 2>/dev/null); do
  if [ "$(readlink "/proc/$pid/cwd" 2>/dev/null)" = "$SANDBOX" ]; then
    echo "❌ a sync.sh run is still in progress (PID $pid); wait for it to finish, then check again"
    exit 1
  fi
done

W=$(mktemp -d "$SANDBOX/.lm/check.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
cp -p sync.sh "$W/sync.sh"
first_line() { head -n 1 "$1" 2>/dev/null | cut -c1-100; }

# ── 1. six copies at once ────────────────────────────────────────────────
mkfifo "$W/go"
for i in 1 2 3 4 5 6; do
  (
    exec 0<"$W/go"                      # blocks until the barrier opens
    s=$(date +%s.%N)
    cd / && SYNC_SECONDS=1 "$W/sync.sh" >"$W/out.$i" 2>&1 </dev/null
    rc=$?
    echo "$rc $s $(date +%s.%N)" > "$W/rc.$i"
  ) &
done
sleep 0.3
exec 3>"$W/go"; exec 3>&-               # release all six together
wait

winners=0; slow=""; silent=""; failed_out=""
for i in 1 2 3 4 5 6; do
  read -r rc s e < "$W/rc.$i"
  if [ "$rc" = 0 ]; then
    winners=$((winners + 1))
  else
    awk -v s="$s" -v e="$e" 'BEGIN { exit !(e - s > 1.0) }' && slow=1
    [ -s "$W/out.$i" ] || silent=1
    failed_out="$W/out.$i"
  fi
done
begins=$(grep -c '^BEGIN' "$W/catalog.db" 2>/dev/null)
if [ "$winners" -eq 0 ]; then
  msg=$(first_line "$failed_out")
  echo "❌ six copies started at once (from /, as cron does) and none did the work${msg:+: $msg}"
  exit 1
fi
if [ "$winners" -gt 1 ] || [ "${begins:-0}" -gt 1 ]; then
  echo "❌ six copies started at the same moment and $winners of them ran the sync (${begins:-0} BEGIN records): runs still overlap"
  exit 1
fi
if [ "${begins:-0}" -ne 1 ] || ! grep -q '^END' "$W/catalog.db"; then
  echo "❌ the copy that won did not write a complete BEGIN/END record to catalog.db"
  exit 1
fi
if [ -n "$slow" ]; then
  echo "❌ a copy that found another one running waited instead of exiting at once (it must give up immediately)"
  exit 1
fi
if [ -n "$silent" ]; then
  echo "❌ a copy that refused to run exited without any message; say why it is not running"
  exit 1
fi

# ── 2. a later run works and holds a lock in the sandbox ─────────────────
(cd / && SYNC_SECONDS=2 "$W/sync.sh" >"$W/out.b" 2>&1 </dev/null; echo $? > "$W/rc.b") &
sleep 0.7
held=""
while IFS= read -r f; do
  flock -n -s "$f" true 2>/dev/null || { held="$f"; break; }
done < <(find "$SANDBOX" -xdev -type f 2>/dev/null)
wait
if [ "$(cat "$W/rc.b")" != 0 ]; then
  echo "❌ after the others finished, the next run refused to start: $(first_line "$W/out.b")"
  exit 1
fi
if [ -z "$held" ]; then
  echo "❌ while sync.sh runs, no file in this directory is locked; a file that just exists is not a lock (look at flock)"
  exit 1
fi

# ── 3. a run killed with kill -9 must not block the next one ─────────────
setsid sh -c 'echo $$ > "$1/victim.pid"; cd / && SYNC_SECONDS=5 exec "$1/sync.sh"' _ "$W" >/dev/null 2>&1 </dev/null &
disown
sleep 0.6
victim=$(cat "$W/victim.pid" 2>/dev/null)
[ -n "$victim" ] && kill -9 -- "-$victim" 2>/dev/null
sleep 0.3
(cd / && SYNC_SECONDS=1 "$W/sync.sh" >"$W/out.c" 2>&1 </dev/null; echo $? > "$W/rc.c")
if [ "$(cat "$W/rc.c")" != 0 ]; then
  echo "❌ a run was killed with kill -9 (no cleanup could run), and after that sync.sh refused to start: $(first_line "$W/out.c")"
  exit 1
fi

echo "✅ only one sync.sh runs at a time, the others give up at once, and a killed run leaves no stale lock"
exit 0
