#!/bin/bash
# deploy.yaml = original with each line's leading whitespace re-expressed as
# spaces (tab stops every 2 columns); everything after the indentation untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
orig=.lm-state/deploy.orig
if [ ! -f deploy.yaml ]; then echo "❌ deploy.yaml is missing; copy deploy.yaml.orig back and try again"; exit 1; fi
if [ ! -s deploy.yaml ]; then echo "❌ deploy.yaml is empty: a redirect into the file you are reading empties it first; write to another file and move it over, or restore it from deploy.yaml.orig"; exit 1; fi

expect=$(mktemp "$SANDBOX/.lm-state/expect.XXXXXX"); trap 'rm -f "$expect"' EXIT
awk '{
  match($0, /^[ \t]*/); lead = substr($0, 1, RLENGTH); rest = substr($0, RLENGTH + 1)
  col = 0
  for (i = 1; i <= length(lead); i++) col = (substr(lead, i, 1) == "\t") ? (int(col / 2) + 1) * 2 : col + 1
  printf "%*s%s\n", col, "", rest
}' "$orig" > "$expect"

if cmp -s deploy.yaml "$expect"; then
  echo "✅ deploy.yaml has space-only indentation and both quoted tabs are intact"
  exit 0
fi
want_tabs=$(grep -c "$(printf '[^[:space:]]\t')" "$expect")
n=$(awk 'BEGIN { FS = "\n" } /^[ ]*\t/ { print NR; exit }' deploy.yaml)
if [ -n "$n" ]; then echo "❌ line $n of deploy.yaml still has a tab in its indentation"; exit 1; fi
got_tabs=$(grep -c "$(printf '[^[:space:]]\t')" deploy.yaml)
if [ "$got_tabs" -lt "$want_tabs" ]; then
  echo "❌ the tabs inside the quoted values were converted too ($got_tabs of $want_tabs lines still have them): only the indentation should change"; exit 1
fi
if [ "$(wc -l < deploy.yaml)" -ne "$(wc -l < "$expect")" ]; then
  echo "❌ deploy.yaml has $(wc -l < deploy.yaml) lines, the original had $(wc -l < "$expect")"; exit 1
fi
n=$(diff deploy.yaml "$expect" | grep -m1 '^[0-9]' | sed 's/[^0-9].*//')
echo "❌ line $n is indented with $(sed -n "${n}p" deploy.yaml | awk '{ match($0, /^ */); print RLENGTH }') spaces, but its level calls for a different amount (a tab goes to the next multiple of 2 columns, not '+2')"
exit 1
