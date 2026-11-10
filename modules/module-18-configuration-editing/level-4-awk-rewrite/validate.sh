#!/bin/bash
# Rack-B rows: weight 0, same alignment. Everything else byte-identical.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f upstreams.tab ]; then
  echo "❌ upstreams.tab is missing"
  exit 1
fi
if cmp -s upstreams.tab .lm-state/original.tab; then
  echo "❌ upstreams.tab has not been changed yet"
  exit 1
fi
if cmp -s upstreams.tab .lm-state/expected.tab; then
  echo "✅ every rack-B backend has weight 0 and the table is still aligned"
  exit 0
fi
if [ "$(wc -l < upstreams.tab)" != "$(wc -l < .lm-state/expected.tab)" ]; then
  echo "❌ upstreams.tab now has $(wc -l < upstreams.tab) lines instead of $(wc -l < .lm-state/expected.tab): rows or comments were lost or added"
  exit 1
fi
# Same line count: compare line by line, report the first problem.
n=0
while IFS= read -r want <&3 && IFS= read -r got <&4; do
  n=$((n + 1))
  [ "$got" = "$want" ] && continue
  case "$want" in
    \#*|"") echo "❌ line $n (a comment or blank line) was modified" ;;
    *)
      set -- $got
      if [ "$#" -eq 5 ] && [ "$5" = "B" ] && [ "$4" != "0" ]; then
        echo "❌ line $n is a rack-B row but its weight is $4, not 0"
      elif [ "$#" -eq 5 ] && [ "$4" = "0" ] && [ "$(printf '%s' "$got" | tr -s ' ')" = "$(printf '%s' "$want" | tr -s ' ')" ]; then
        echo "❌ line $n has weight 0 but the columns are no longer aligned like the rest of the file"
      elif [ "$#" -eq 5 ] && [ "$5" != "B" ] && [ "$(printf '%s' "$want" | awk '{print $5}')" != "B" ]; then
        echo "❌ line $n is not a rack-B row but it was changed"
      else
        echo "❌ line $n differs from what it should be"
      fi ;;
  esac
  exit 1
done 3< .lm-state/expected.tab 4< upstreams.tab
echo "❌ upstreams.tab does not match the expected result"
exit 1
