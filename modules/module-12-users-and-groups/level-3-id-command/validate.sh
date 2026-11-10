#!/bin/bash
# missing.txt = hosts whose captured `id deploy` has no www-data group at all
# (primary gid or supplementary); me.txt = "UID GID" of whoever runs this.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

has_www() { grep -Eq '(gid=|groups=|,)[0-9]+\(www-data\)' "id-$1.txt"; }

WANT=""
for f in id-*.txt; do
  [ -f "$f" ] || continue
  h=${f#id-}; h=${h%.txt}
  has_www "$h" || WANT="$WANT$h
"
done
WANT=$(printf '%s' "$WANT" | LC_ALL=C sort)
if [ "$(ls id-*.txt 2>/dev/null | wc -l | tr -d ' ')" != 5 ] || [ -z "$WANT" ]; then
  echo "❌ the captured id-*.txt files are missing or were edited; type 'reset' to get them back"
  exit 1
fi

if [ ! -f missing.txt ]; then
  echo "❌ missing.txt does not exist yet"
  exit 1
fi
GOT=$(tr -d '\r' < missing.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^id-//' -e 's/\.txt$//' | grep -v '^$' | LC_ALL=C sort)
if [ "$GOT" != "$WANT" ]; then
  if [ -z "$GOT" ]; then
    echo "❌ missing.txt is empty"
    exit 1
  fi
  while IFS= read -r h; do
    printf '%s\n' "$WANT" | grep -qxF -- "$h" && continue
    if [ ! -f "id-$h.txt" ]; then
      echo "❌ '$h' is not one of the five hosts; write host names like web-01, one per line"
    elif grep -q 'gid=33(www-data)' "id-$h.txt"; then
      echo "❌ on $h deploy's primary group is www-data (gid=33): a primary group gives access just like a supplementary one"
    else
      echo "❌ deploy on $h is in www-data, so $h is not missing it"
    fi
    exit 1
  done <<< "$GOT"
  for h in $WANT; do
    printf '%s\n' "$GOT" | grep -qxF -- "$h" && continue
    if grep -q '(www-data-ro)' "id-$h.txt"; then
      echo "❌ a host is missing from missing.txt: www-data-ro is a different group from www-data"
    else
      echo "❌ a host where deploy has no www-data group at all is missing from missing.txt"
    fi
    exit 1
  done
fi

if [ ! -f me.txt ]; then
  echo "❌ the hosts are right; now write your own numeric identity to me.txt"
  exit 1
fi
read -r a b extra < <(tr -d '\r' < me.txt | grep -v '^[[:space:]]*$' | head -n 1)
if [ -n "$extra" ] || ! [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ ]]; then
  echo "❌ me.txt should hold just two numbers, your UID and your primary GID, like: 1000 1000"
  exit 1
fi
if [ "$a" != "$(id -u)" ]; then
  echo "❌ the first number in me.txt is not your UID"
  exit 1
fi
if [ "$b" != "$(id -g)" ]; then
  echo "❌ the second number in me.txt is not your primary GID"
  exit 1
fi
echo "✅ missing.txt names the host(s) without www-data, and me.txt holds your UID and GID"
exit 0
