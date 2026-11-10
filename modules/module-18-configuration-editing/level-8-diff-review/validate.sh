#!/bin/bash
# changed.txt = set of directives with a changed value.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cksum haproxy.orig.cfg haproxy.cfg 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ one of the haproxy files was changed; review it, do not edit it (type 'reset' to restore)"
  exit 1
fi
if [ ! -f changed.txt ]; then
  echo "❌ changed.txt does not exist yet"
  exit 1
fi
got=$(tr -d '\r' < changed.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | LC_ALL=C sort -u)
want=$(LC_ALL=C sort .lm-state/want)
if [ "$got" = "$want" ]; then
  echo "✅ changed.txt names the 3 directives that really changed"
  exit 0
fi
if [ -z "$got" ]; then
  echo "❌ changed.txt is empty"
  exit 1
fi
while IFS= read -r k; do
  if ! printf '%s\n' "$want" | grep -qxF -- "$k"; then
    if grep -qE "^[[:space:]]*$k([[:space:]]|\$)" haproxy.cfg; then
      echo "❌ '$k' is in the file, but its value is the same in both versions (only whitespace differs)"
    else
      echo "❌ '$k' is not a directive of haproxy.cfg: list the directive name only, not the whole line"
    fi
    exit 1
  fi
done <<< "$got"
echo "❌ changed.txt is incomplete: $(( $(echo "$want" | wc -l) - $(echo "$got" | wc -l) )) changed directive(s) missing (one of them is a single number inside a long list of whitespace noise)"
exit 1
