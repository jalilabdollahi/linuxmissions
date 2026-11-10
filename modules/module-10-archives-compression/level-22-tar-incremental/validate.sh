#!/bin/bash
# $1 = sandbox path
# 1. backups/data-{sun,mon,tue,wed}.tar.gz exist, in GNU incremental format;
#    sun is full, the others hold only changes, each taken on its own day.
# 2. Replaying the four archives with --listed-incremental gives Wednesday's
#    state (fingerprint recorded by simulate-day.sh thu).
# 3. restored/data is exactly Wednesday's state, deletions included.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

state() {  # fingerprint lines of a data dir: names, types and checksums
  ( cd "$1" && find . -print | LC_ALL=C sort | while IFS= read -r p; do
      if [ -f "$p" ]; then echo "f $p $(cksum < "$p")"; else echo "d $p"; fi
    done )
}
is_incremental() {  # GNU incremental archives carry dumpdir ('D') members
  python3 -c 'import sys, tarfile
sys.exit(0 if any(m.type == b"D" for m in tarfile.open(sys.argv[1])) else 1)' "$1" 2>/dev/null
}
has() { tar -tzf "backups/data-$1.tar.gz" 2>/dev/null | grep -qx "$2"; }

day=$(cat .simulate/day 2>/dev/null)
[ -x simulate-day.sh ] && [ -n "$day" ] || { echo "❌ simulate-day.sh or its state is missing; type 'reset'"; exit 1; }

idx() { case $1 in sun) echo 0;; mon) echo 1;; tue) echo 2;; wed) echo 3;; thu) echo 4;; *) echo 9;; esac; }
prev=""
for d in sun mon tue wed; do
  a="backups/data-$d.tar.gz"
  if [ ! -f "$a" ]; then
    if [ "$(idx "$day")" -gt "$(idx "$d")" ]; then
      echo "❌ $a is gone, and the week can't be replayed without it; type 'reset'"
    elif [ "$day" = "$d" ] && [ "$d" = sun ]; then
      echo "❌ $a (Sunday's full backup, with a snapshot file) does not exist yet"
    elif [ "$day" = "$d" ]; then
      echo "❌ it is $d now: take $a"
    else
      echo "❌ backups/data-$prev.tar.gz is taken; play the next day with ./simulate-day.sh $d"
    fi
    exit 1
  fi
  if ! is_incremental "$a"; then
    echo "❌ $a is a plain tar, not a GNU incremental archive (create it with --listed-incremental=SNAPSHOT-FILE)"
    exit 1
  fi
  if [ "$d" = sun ]; then
    has sun data/static/logo.png || { echo "❌ backups/data-sun.tar.gz must be a full (level 0) backup of data/"; exit 1; }
  else
    if has "$d" data/static/logo.png; then
      echo "❌ $a contains data/static/logo.png, which hasn't changed since Sunday: it is a full backup, not an incremental (reuse the snapshot file)"
      exit 1
    fi
  fi
  case $d in
    mon) has mon data/orders/2026-11-09.csv || { echo "❌ $a doesn't hold Monday's changes (run ./simulate-day.sh mon before this backup)"; exit 1; }
         has mon data/orders/2026-11-10.csv && { echo "❌ $a already holds Tuesday's changes: back up each day before playing the next"; exit 1; } ;;
    tue) has tue data/orders/2026-11-10.csv || { echo "❌ $a doesn't hold Tuesday's changes"; exit 1; }
         has tue data/orders/2026-11-11.csv && { echo "❌ $a already holds Wednesday's changes: back up each day before playing the next"; exit 1; } ;;
    wed) has wed data/orders/2026-11-11.csv || { echo "❌ $a doesn't hold Wednesday's changes"; exit 1; } ;;
  esac
  prev=$d
done

if [ "$day" != thu ]; then
  echo "❌ all four backups are there; now play Thursday with ./simulate-day.sh thu"
  exit 1
fi
want=$(cat .simulate/wed.state 2>/dev/null)
[ -n "$want" ] || { echo "❌ the simulation state is missing; type 'reset'"; exit 1; }

# Replay the chain ourselves: does it rebuild Wednesday?
tmp=$(mktemp -d "${TMPDIR:-/tmp}/lm-incr.XXXXXX")
for d in sun mon tue wed; do
  tar --listed-incremental=/dev/null -xzf "backups/data-$d.tar.gz" -C "$tmp" 2>/dev/null
done
chain=$(state "$tmp/data" 2>/dev/null)
rm -rf "$tmp"
if [ "$chain" != "$want" ]; then
  echo "❌ replaying the four backups in order does not rebuild Wednesday's data/; the chain is broken (snapshot file reused correctly?)"
  exit 1
fi

if [ ! -d restored/data ]; then
  echo "❌ the backups are good; now restore Wednesday's state into restored/ (restored/data/...)"
  exit 1
fi
got=$(state restored/data)
if [ "$got" != "$want" ]; then
  extra=$(printf '%s\n' "$got" | cut -d' ' -f1,2 | grep -vxF -e "$(printf '%s\n' "$want" | cut -d' ' -f1,2)" | head -1 | cut -d' ' -f2)
  missing=$(printf '%s\n' "$want" | cut -d' ' -f1,2 | grep -vxF -e "$(printf '%s\n' "$got" | cut -d' ' -f1,2)" | head -1 | cut -d' ' -f2)
  if [ -n "$extra" ]; then
    echo "❌ restored/data/${extra#./} exists, but it was gone by Wednesday: extract with --listed-incremental=/dev/null so tar replays deletions"
  elif [ -n "$missing" ]; then
    echo "❌ restored/data/${missing#./} is missing: restore the full backup and then every incremental, in order"
  else
    echo "❌ restored/data has the right files, but some content is not Wednesday's (restore the archives oldest first)"
  fi
  exit 1
fi
echo "✅ a full + 3 incrementals in backups/, and restored/data is exactly Wednesday's state"
exit 0
