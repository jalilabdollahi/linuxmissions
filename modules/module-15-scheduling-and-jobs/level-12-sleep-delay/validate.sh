#!/bin/bash
# Run wait_ready.sh twice in parallel against probe states the validator
# controls: (A) no argument, app ready after R = 4..8 s: exit 0, at most ~2 s
# after R, probe called no more than every 2 s; (B) argument 6, never ready:
# exit 1 after 5..9 s with 3..5 probe calls. A failing result is cached per
# script content so the game does not wait ~10 s after every command.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SCRIPT="$SANDBOX/wait_ready.sh"

if [ "$(cksum < probe 2>/dev/null)" != "918939798 890" ]; then
  echo "❌ ./probe was changed; it stands for the real app, so leave it as it is (type reset)"
  exit 1
fi
if [ ! -f "$SCRIPT" ]; then
  echo "❌ wait_ready.sh does not exist yet"
  exit 1
fi
if [ ! -x "$SCRIPT" ]; then
  echo "❌ wait_ready.sh is not executable, so the deploy hook cannot run ./wait_ready.sh"
  exit 1
fi
if ! bash -n "$SCRIPT" 2>/dev/null; then
  echo "❌ wait_ready.sh has a syntax error: $(bash -n "$SCRIPT" 2>&1 | head -n 1 | sed 's|.*wait_ready.sh: ||')"
  exit 1
fi

CACHE="${TMPDIR:-/tmp}/lm-m15-wait-ready-$(id -u)"
KEY="$( (printf '%s\n' "$SANDBOX"; cat "$SCRIPT") | cksum | tr ' ' '-')"
if [ -f "$CACHE/$KEY" ]; then
  cat "$CACHE/$KEY"
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/a" "$WORK/b"
R=$((4 + RANDOM % 5))
echo "$R" > "$WORK/a/ready_after"
touch "$WORK/b/never"

run() {  # DIR ARGS... ; records start, end and exit status
  local dir="$1"; shift
  local t0="$EPOCHREALTIME"
  echo "$t0" > "$dir/first"
  PROBE_STATE="$dir" timeout -k 1 14 "$SCRIPT" "$@" < /dev/null > "$dir/out" 2>&1
  echo "$? $t0 $EPOCHREALTIME" > "$dir/result"
}
run "$WORK/a" &
run "$WORK/b" 6 &
wait

verdict="$(python3 - "$WORK" "$R" <<'PY'
import sys

work, ready_after = sys.argv[1], float(sys.argv[2])


def load(d):
    code, t0, t1 = open(f"{work}/{d}/result").read().split()
    try:
        calls = [float(x) for x in open(f"{work}/{d}/calls").read().split()]
    except OSError:
        calls = []
    return int(code), float(t0), float(t1), calls


def gaps_ok(calls):
    return all(b - a >= 1.8 for a, b in zip(calls, calls[1:]))


code, t0, t1, calls = load("a")
ready_at = t0 + ready_after
if code == 124 or code == 137:
    print(f"❌ with an app that is ready after {ready_after:.0f}s, wait_ready.sh was still running after 14s")
elif not calls:
    print("❌ wait_ready.sh never ran ./probe")
elif not gaps_ok(calls) and len(calls) > 2:
    print(f"❌ wait_ready.sh called ./probe {len(calls)} times in {t1 - t0:.0f}s; it hammers the app, poll every 2 seconds")
elif code != 0:
    print(f"❌ with an app that is ready after {ready_after:.0f}s, wait_ready.sh exited {code} after {t1 - t0:.1f}s instead of 0")
elif t1 < ready_at:
    print("❌ wait_ready.sh exited 0 before the app was ready")
elif t1 - ready_at > 2.6:
    print(f"❌ the app was ready after {ready_after:.0f}s but wait_ready.sh only noticed {t1 - ready_at:.1f}s later; poll every 2 seconds")
else:
    code, t0, t1, calls = load("b")
    took = t1 - t0
    if code == 124 or code == 137:
        print("❌ with `wait_ready.sh 6` and an app that never comes up, it was still waiting after 14s; use the timeout from the first argument")
    elif not gaps_ok(calls) and len(calls) > 2:
        print(f"❌ against an app that never comes up, wait_ready.sh called ./probe {len(calls)} times in {took:.0f}s; poll every 2 seconds")
    elif code != 1:
        print(f"❌ `wait_ready.sh 6` against an app that never comes up exited {code} after {took:.1f}s; on a timeout it must exit 1")
    elif took < 5.0:
        print(f"❌ `wait_ready.sh 6` gave up after {took:.1f}s; it should keep trying for 6 seconds")
    elif took > 9.0:
        print(f"❌ `wait_ready.sh 6` gave up only after {took:.1f}s; the first argument is the timeout in seconds")
    elif len(calls) < 3:
        print(f"❌ `wait_ready.sh 6` probed only {len(calls)} times in {took:.0f}s; probe every 2 seconds until the timeout")
    else:
        print(f"✅ wait_ready.sh noticed readiness within 2s and gave up after {took:.1f}s with exit 1")
PY
)"
echo "$verdict"
case "$verdict" in
  ✅*) exit 0 ;;
esac
mkdir -p "$CACHE" && printf '%s\n' "$verdict" > "$CACHE/$KEY"
exit 1
