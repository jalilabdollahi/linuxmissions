#!/bin/bash
# app.log.2 .. app.log.12 must be gzip files with the original content; the
# live log, app.log.1 and the old .gz files must be untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/rotated.sums ] || [ ! -s .lm-state/keep.sums ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi

while read -r f inode sum size; do
  if [ ! -f "logs/$f" ]; then
    if [ -f "logs/$f.gz" ]; then
      case "$f" in
        app.log) echo "❌ app.log was compressed, but the app is still writing to it; get it back with gunzip and leave it plain" ;;
        *) echo "❌ $f was compressed; with delaycompress it stays plain until the next rotation (gunzip it back)" ;;
      esac
    else
      echo "❌ logs/$f is gone; type 'reset' to start over"
    fi
    exit 1
  fi
  if [ "$(cksum < "logs/$f")" != "$sum $size" ]; then
    echo "❌ logs/$f was changed; it must stay exactly as it was"
    exit 1
  fi
  # Only the live log must be the very same file: the app holds it open.
  if [ "$f" = app.log ] && [ "$(ls -i logs/app.log | awk '{print $1}')" != "$inode" ]; then
    echo "❌ logs/app.log has the right content but is a new file; the running app still writes to the old, deleted one. Type 'reset' and leave app.log alone"
    exit 1
  fi
done < .lm-state/keep.sums

left=""
while read -r n sum size; do
  [ -f "logs/app.log.$n" ] && left="$left app.log.$n"
done < .lm-state/rotated.sums
if [ -n "$left" ]; then
  echo "❌ still uncompressed in logs/:$left"
  exit 1
fi
while read -r n sum size; do
  gz="logs/app.log.$n.gz"
  if [ ! -f "$gz" ]; then
    echo "❌ logs/app.log.$n.gz does not exist"
    exit 1
  fi
  if ! gzip -t "$gz" 2>/dev/null; then
    echo "❌ logs/app.log.$n.gz is not a valid gzip file"
    exit 1
  fi
  if [ "$(gzip -dc "$gz" | cksum)" != "$sum $size" ]; then
    echo "❌ logs/app.log.$n.gz does not unpack to the original app.log.$n"
    exit 1
  fi
done < .lm-state/rotated.sums

extra=$(cd logs && ls -A | grep -vxE 'app\.log|app\.log\.1|app\.log\.([2-9]|1[0-4])\.gz' | head -1)
if [ -n "$extra" ]; then
  echo "❌ logs/$extra should not be there; logs/ should hold only app.log, app.log.1 and app.log.2.gz ... app.log.14.gz"
  exit 1
fi
echo "✅ app.log.2 to app.log.12 are gzipped, app.log and app.log.1 are untouched"
exit 0
