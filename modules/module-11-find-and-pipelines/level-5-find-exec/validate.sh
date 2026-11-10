#!/bin/bash
# Old .log files must be .gz with their original content; everything else
# (recent logs, non-.log files, the existing .gz) unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/gzip ] || [ ! -s .lm-state/keep ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi

days() { awk -v m="$1" 'BEGIN { printf "%.1f", m / 1440 }'; }

while IFS=$'\t' read -r f sum age; do
  if [ -f "$f.gz" ]; then
    case $f in
      *.log) echo "❌ $f.gz exists, but $f is only $(days "$age") days old and must stay uncompressed (type 'reset')" ;;
      *)     echo "❌ $f.gz exists, but $f does not end in .log and must stay as it is (type 'reset')" ;;
    esac
    exit 1
  fi
  if [ ! -f "$f" ]; then
    echo "❌ $f is gone; type 'reset' to restore app/logs"
    exit 1
  fi
  if [ "$(cksum < "$f")" != "$sum" ]; then
    echo "❌ $f was changed; it must stay exactly as it was (type 'reset')"
    exit 1
  fi
done < .lm-state/keep

while IFS=$'\t' read -r f sum age; do
  if [ -f "$f" ]; then
    echo "❌ $f is $(days "$age") days old and still not compressed"
    exit 1
  fi
  if [ ! -f "$f.gz" ]; then
    echo "❌ $f is gone, but there is no $f.gz; was it deleted instead of compressed? (type 'reset')"
    exit 1
  fi
  if [ "$(gzip -dc < "$f.gz" 2>/dev/null | cksum)" != "$sum" ]; then
    echo "❌ $f.gz does not hold the original content of $f (compressed twice? type 'reset')"
    exit 1
  fi
done < .lm-state/gzip

extra=$(find app/logs -name '*.gz' | sed 's|^\./||' | while IFS= read -r g; do
  cut -f1 .lm-state/keep | grep -qxF -- "$g" && continue
  cut -f1 .lm-state/gzip | sed 's/$/.gz/' | grep -qxF -- "$g" && continue
  echo "$g"
done | head -1)
if [ -n "$extra" ]; then
  echo "❌ $extra should not exist; only old .log files get compressed (type 'reset')"
  exit 1
fi
echo "✅ the $(wc -l < .lm-state/gzip | tr -d ' ') logs older than 7 days are gzipped, everything else is untouched"
exit 0
