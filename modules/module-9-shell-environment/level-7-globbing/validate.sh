#!/bin/bash
# archive/oct-2 must hold exactly app-2026-10-10.log .. app-2026-10-19.log,
# and every other file must still be in logs/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -d logs ]; then
  echo "❌ logs/ is missing; type reset to start over"
  exit 1
fi
if [ ! -d archive/oct-2 ]; then
  echo "❌ archive/oct-2/ does not exist yet"
  exit 1
fi

want=""
for d in 10 11 12 13 14 15 16 17 18 19; do want="$want app-2026-10-$d.log"; done
got="$(cd archive/oct-2 && ls -A | sort | tr '\n' ' ')"

# What else ended up in the archive?
for f in $(cd archive/oct-2 && ls -A); do
  case " $want " in *" $f "*) continue ;; esac
  case "$f" in
    *.gz) echo "❌ archive/oct-2 has $f: your pattern also matches the compressed copies (*.log.gz)" ;;
    app-2026-10-1.log|app-2026-10-100.log) echo "❌ archive/oct-2 has the malformed $f: '*' matches any number of characters, even none" ;;
    .*) echo "❌ archive/oct-2 has the hidden file $f, which is not a log" ;;
    *) echo "❌ archive/oct-2 has $f, which is not one of the ten logs for 10-19 October" ;;
  esac
  exit 1
done
if [ -n "$(cd archive && ls -A | grep -vx oct-2)" ]; then
  echo "❌ archive/ has files outside oct-2/: $(cd archive && ls -A | grep -vx oct-2 | head -1)"
  exit 1
fi

for f in $want; do
  if [ ! -f "archive/oct-2/$f" ]; then
    if [ -f "logs/$f" ]; then
      echo "❌ logs/$f is still in logs/ (archive/oct-2 has $(cd archive/oct-2 && ls -A | wc -l | tr -d ' ') of the 10 files)"
    else
      echo "❌ $f is in neither logs/ nor archive/oct-2/; type reset to start over"
    fi
    exit 1
  fi
  if [ "$(head -1 "archive/oct-2/$f")" != "# $f" ]; then
    echo "❌ archive/oct-2/$f does not hold the original log; move the files, don't recreate them"
    exit 1
  fi
done

# Everything else is still in logs/.
for d in $(seq -w 1 31); do
  case "$d" in 1?) ;; *) [ -f "logs/app-2026-10-$d.log" ] || { echo "❌ logs/app-2026-10-$d.log is gone; only 10-19 October should move"; exit 1; } ;; esac
  if [ "$d" -le 20 ] && [ ! -f "logs/app-2026-10-$d.log.gz" ]; then
    echo "❌ logs/app-2026-10-$d.log.gz is gone; the compressed copies stay in logs/"
    exit 1
  fi
done
for f in app-2026-09-28.log app-2026-09-29.log app-2026-09-30.log app-2026-11-01.log app-2026-11-02.log app-2026-11-03.log \
         worker-2026-10-12.log worker-2026-10-14.log worker-2026-10-17.log app-2026-10-1.log app-2026-10-100.log .app-2026-10-12.log.swp; do
  if [ ! -f "logs/$f" ]; then
    echo "❌ logs/$f is gone; it should stay in logs/"
    exit 1
  fi
done
if [ "$(ls -A logs | wc -l | tr -d ' ')" -ne 53 ]; then
  echo "❌ logs/ should hold 53 files after the move, it has $(ls -A logs | wc -l | tr -d ' ')"
  exit 1
fi

echo "✅ archive/oct-2 holds exactly the ten app logs for 10-19 October"
exit 0
