#!/bin/bash
# recent.txt = the files setup aged to less than 24 h (saved in .lm-state, so
# the answer does not drift while the player works).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/recent ] || [ ! -s .lm-state/ages ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
while IFS= read -r f; do
  if [ ! -f "$f" ]; then
    echo "❌ $f is gone; type 'reset' to restore etc/"
    exit 1
  fi
done < .lm-state/recent

if [ ! -f recent.txt ]; then
  echo "❌ recent.txt does not exist yet"
  exit 1
fi
GOT=$(tr -d '\r' < recent.txt | sed -e "s|^$SANDBOX/||" -e 's|^\./||' -e 's|/$||' | grep -v '^[[:space:]]*$' | LC_ALL=C sort)
WANT=$(cat .lm-state/recent)
if [ "$GOT" = "$WANT" ]; then
  echo "✅ recent.txt lists the $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') configs changed in the last 24 hours"
  exit 0
fi
if [ -z "$GOT" ]; then
  echo "❌ recent.txt is empty"
  exit 1
fi
if [ -n "$(printf '%s\n' "$GOT" | uniq -d)" ]; then
  echo "❌ recent.txt lists a path more than once"
  exit 1
fi
while IFS= read -r line; do
  printf '%s\n' "$WANT" | grep -qxF -- "$line" && continue
  hours=$(awk -v f="$line" '$1 == f { print $2 }' .lm-state/ages)
  if [ -d "$line" ]; then
    echo "❌ recent.txt lists $line, which is a directory; only files count"
  elif [ -z "$hours" ]; then
    echo "❌ recent.txt has a line that is not a config file under etc/: $line"
  elif [ "$hours" -lt 48 ]; then
    echo "❌ recent.txt lists $line, which was modified more than 24 hours ago (but less than 48)"
  else
    echo "❌ recent.txt lists $line, whose content was last modified about $(( hours / 24 )) days ago (a recent access or status-change time does not count)"
  fi
  exit 1
done <<< "$GOT"
echo "❌ recent.txt lists $(printf '%s\n' "$GOT" | wc -l | tr -d ' ') file(s), but $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') were modified in the last 24 hours"
exit 1
