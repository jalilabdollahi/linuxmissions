#!/bin/bash
# hits.txt = every "file:line" whose line contains a leaked key as a literal
# substring (computed by setup with awk index(), no regex).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/hits ] || [ ! -s .lm-state/total ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ "$(cat logs/*/*.log 2>/dev/null | wc -l | tr -d ' ')" != "$(cat .lm-state/total)" ]; then
  echo "❌ the files in logs/ were changed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f hits.txt ]; then
  echo "❌ hits.txt does not exist yet"
  exit 1
fi
GOT=$(tr -d '\r' < hits.txt | sed -e "s|^$SANDBOX/||" -e 's|^\./||' | grep -v '^$' | LC_ALL=C sort)
WANT=$(cat .lm-state/hits)
if [ "$GOT" = "$WANT" ]; then
  echo "✅ hits.txt holds the $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') log lines that used a leaked key"
  exit 0
fi
if [ -z "$GOT" ]; then
  echo "❌ hits.txt is empty"
  exit 1
fi
n_got=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
if [ "$n_got" -ge "$(cat .lm-state/total)" ]; then
  echo "❌ hits.txt has all $n_got log lines; one of the patterns matches everything (look at the end of leaked.txt)"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -qE '^logs/[^:]*\.log:[0-9]+:'; then
  echo "❌ hits.txt contains line numbers; write file:line only"
  exit 1
fi
if ! printf '%s\n' "$GOT" | grep -q '^logs/[^:]*\.log:2026'; then
  echo "❌ each line must start with the log file's path, like logs/api/access-2026-11-09.log:2026-11-09T..."
  exit 1
fi
extra=$(printf '%s\n' "$GOT" | grep -vxF -f .lm-state/hits | wc -l | tr -d ' ')
missing=$(printf '%s\n' "$WANT" | grep -vxF -f <(printf '%s\n' "$GOT") | wc -l | tr -d ' ')
if [ "$extra" -gt 0 ]; then
  echo "❌ $extra line(s) in hits.txt contain none of the keys as written (a . or * read as a regex matches other text)"
elif [ "$missing" -gt 0 ]; then
  echo "❌ hits.txt misses $missing line(s) that contain a leaked key (as a regex, $ and * in a key stop matching itself)"
else
  echo "❌ hits.txt lists some lines more than once"
fi
exit 1
