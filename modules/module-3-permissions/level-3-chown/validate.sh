#!/bin/bash
SANDBOX="$1"
LIST="$SANDBOX/paths.txt"
ME=$(id -un)

owner_group() {
  stat -c '%U %G' "$1" 2>/dev/null || stat -f '%Su %Sg' "$1"
}

if [ ! -s "$LIST" ]; then
  echo "❌ paths.txt is missing (type reset to get it back)"
  exit 1
fi
if [ ! -f "$SANDBOX/owners.txt" ]; then
  echo "❌ owners.txt not found"
  exit 1
fi

TOTAL=$(grep -c . "$LIST")
WRONG=0
while IFS= read -r p; do
  [ -z "$p" ] && continue
  want=$(owner_group "$p")
  line=$(awk -v p="$p" '$1 == p' "$SANDBOX/owners.txt" | head -1)
  rest=${line#"$p"}
  rest=${rest//:/ }          # accept "owner:group" as well as "owner group"
  read -r o g extra <<< "$rest"
  if [ -z "$line" ] || [ "$o $g" != "$want" ] || [ -n "$extra" ]; then
    WRONG=$((WRONG + 1))
  fi
done < "$LIST"
if [ "$WRONG" -gt 0 ]; then
  echo "❌ owners.txt: $WRONG of $TOTAL paths are missing or have the wrong owner/group"
  exit 1
fi
LINES=$(grep -c . "$SANDBOX/owners.txt")
if [ "$LINES" -ne "$TOTAL" ]; then
  echo "❌ owners.txt has $LINES lines, expected one per path in paths.txt ($TOTAL)"
  exit 1
fi

if [ ! -f "$SANDBOX/fixable.txt" ]; then
  echo "❌ owners.txt is right; now write fixable.txt"
  exit 1
fi
want_fix=$(while IFS= read -r p; do
  [ -n "$p" ] && [ "$(owner_group "$p" | cut -d' ' -f1)" = "$ME" ] && echo "$p"
done < "$LIST" | sort)
got_fix=$(sed -e 's/[[:space:]]*$//' -e '/^$/d' "$SANDBOX/fixable.txt" | sort -u)
if [ "$got_fix" != "$want_fix" ]; then
  n_want=$(printf '%s\n' "$want_fix" | grep -c .)
  n_got=$(printf '%s\n' "$got_fix" | grep -c .)
  echo "❌ fixable.txt lists $n_got path(s); it should list exactly the $n_want path(s) owned by $ME"
  exit 1
fi

echo "✅ Ownership audit complete: you can change $(printf '%s\n' "$want_fix" | grep -c .) of the $TOTAL paths yourself"
exit 0
