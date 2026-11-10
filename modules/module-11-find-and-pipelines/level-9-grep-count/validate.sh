#!/bin/bash
# noisy.txt = "<file> <count>" for logs with > 50 ERROR-level lines, count desc.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/noisy ] || [ ! -s .lm-state/counts ] || [ ! -s .lm-state/logs.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ "$(cksum logs/*.log 2>/dev/null | cksum)" != "$(cat .lm-state/logs.sum)" ]; then
  echo "❌ the logs in logs/ were changed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f noisy.txt ]; then
  echo "❌ noisy.txt does not exist yet"
  exit 1
fi
# Accept logs/x.log or x.log, tabs or spaces, a colon instead of the space.
GOT=$(tr -d '\r' < noisy.txt | sed -e 's|^\./||' -e 's|^logs/||' -e 's/^\([^ :	]*\.log\)[:	 ][	 ]*/\1 /' -e 's/[[:space:]]*$//' | grep -v '^$')
WANT=$(cat .lm-state/noisy)
if [ "$GOT" = "$WANT" ]; then
  echo "✅ noisy.txt ranks the $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') services with more than 50 ERROR lines"
  exit 0
fi
if [ -z "$GOT" ]; then
  echo "❌ noisy.txt is empty"
  exit 1
fi
while IFS= read -r line; do
  f=${line%% *}; n=${line#* }
  real=$(awk -v f="$f" '$1 == f { print $2 }' .lm-state/counts)
  if [ -z "$real" ] || [ "$f" = "$line" ]; then
    echo "❌ this line is not '<file> <count>' for a log in logs/: $line"
    exit 1
  fi
  if [ "$n" != "$real" ]; then
    echo "❌ $f: $n is not its number of ERROR-level lines (count lines, and only the level ERROR)"
    exit 1
  fi
  if [ "$real" -le 50 ]; then
    echo "❌ $f has $real ERROR lines, which is not more than 50"
    exit 1
  fi
done <<< "$GOT"
if [ -n "$(printf '%s\n' "$GOT" | sort | uniq -d)" ]; then
  echo "❌ noisy.txt lists a log more than once"
  exit 1
fi
n_got=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
n_want=$(printf '%s\n' "$WANT" | wc -l | tr -d ' ')
if [ "$n_got" -lt "$n_want" ]; then
  echo "❌ noisy.txt lists $n_got logs, but $n_want have more than 50 ERROR lines"
else
  echo "❌ the right logs and counts, but not sorted by count, highest first"
fi
exit 1
