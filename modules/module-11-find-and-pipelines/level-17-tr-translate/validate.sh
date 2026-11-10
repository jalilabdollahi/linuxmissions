#!/bin/bash
# usernames.txt = newhires.txt line by line: no CR, lowercase, every run of
# spaces / tabs / dots replaced by a single underscore.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/newhires.sum ] || [ "$(cksum < newhires.txt 2>/dev/null)" != "$(cat .lm-state/newhires.sum)" ]; then
  echo "❌ newhires.txt was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f usernames.txt ]; then
  echo "❌ usernames.txt does not exist yet"
  exit 1
fi

EXPECTED=$(awk '{ sub(/\r$/, ""); $0 = tolower($0); gsub(/[ \t.]+/, "_"); print }' newhires.txt)
if [ "$(cat usernames.txt)" = "$EXPECTED" ]; then
  echo "✅ usernames.txt has all $(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ') usernames, clean"
  exit 0
fi

if [ "$(tr -cd '\r' < usernames.txt | wc -c)" -gt 0 ]; then
  echo "❌ usernames.txt still has carriage returns (\\r) from the Windows line endings; useradd would put them into the names"
  exit 1
fi
want=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
got=$(grep -c '' usernames.txt)
if [ "$got" -ne "$want" ]; then
  echo "❌ usernames.txt has $got lines, but newhires.txt has $want names (one username per line, in the same order)"
  exit 1
fi
if grep -q '[A-Z]' usernames.txt; then
  echo "❌ usernames.txt still has capital letters, e.g. $(grep -m1 '[A-Z]' usernames.txt)"
  exit 1
fi
if grep -q '[[:space:].]' usernames.txt; then
  echo "❌ usernames.txt still has spaces, tabs or dots, e.g. '$(grep -m1 '[[:space:].]' usernames.txt)'"
  exit 1
fi
if grep -q '__' usernames.txt; then
  echo "❌ some usernames have repeated underscores, e.g. $(grep -m1 '__' usernames.txt): squeeze each run into one _"
  exit 1
fi
n=$(paste -d'\n' <(printf '%s\n' "$EXPECTED") usernames.txt | awk 'NR % 2 { w = $0; next } $0 != w { print NR / 2; exit }')
echo "❌ line $n of usernames.txt is not the username for line $n of newhires.txt"
exit 1
