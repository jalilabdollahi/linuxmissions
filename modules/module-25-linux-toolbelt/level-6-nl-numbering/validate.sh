#!/bin/bash
# review.txt = every line of nginx.conf as "%3d: <line>", blank lines included.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ "$(cksum < nginx.conf 2>/dev/null)" != "$(cat .lm-state/conf.sum)" ]; then
  echo "❌ nginx.conf was changed; type 'reset' to restore it"; exit 1
fi
if [ ! -f review.txt ]; then echo "❌ review.txt does not exist yet"; exit 1; fi
expect=$(mktemp "$SANDBOX/.lm-state/expect.XXXXXX"); trap 'rm -f "$expect"' EXIT
awk '{ printf "%3d: %s\n", NR, $0 }' nginx.conf > "$expect"
if cmp -s review.txt "$expect"; then
  echo "✅ review.txt: all $(wc -l < "$expect" | tr -d ' ') lines numbered like the editor"
  exit 0
fi
want=$(wc -l < "$expect" | tr -d ' '); got=$(wc -l < review.txt | tr -d ' ')
nonblank=$(grep -c '[^[:space:]]' nginx.conf)
if [ "$got" -ne "$want" ]; then
  echo "❌ review.txt has $got lines, nginx.conf has $want"
elif grep -q '^ *[0-9]*:' review.txt && [ "$(grep -cE '^ *[0-9]+: *$' review.txt)" -lt "$(grep -c '^[[:space:]]*$' nginx.conf)" ]; then
  echo "❌ some blank lines have no number: the numbers drift away from the editor's after the first blank line"
else
  n=$(diff review.txt "$expect" | grep -m1 '^[0-9]' | sed 's/[^0-9].*//')
  echo "❌ line $n of review.txt is not formatted as expected: '$(sed -n "${n}p" review.txt)' (number right-aligned in 3, then a colon and one space)"
fi
exit 1
