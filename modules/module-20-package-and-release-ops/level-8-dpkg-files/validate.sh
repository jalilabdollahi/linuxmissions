#!/bin/bash
# owners.tsv: one "path<TAB>package|none" line per suspect, matching the
# owners fixed at setup (the real dpkg database was built from them).
SANDBOX="$1"
F="$SANDBOX/owners.tsv"
if [ ! -f "$F" ]; then
  echo "❌ owners.tsv does not exist yet"
  exit 1
fi
N=$(grep -c . "$F")
if [ "$N" -ne 6 ]; then
  echo "❌ owners.tsv has $N lines, expected one for each of the 6 suspects"
  exit 1
fi
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    *$'\t'*) ;;
    *) echo "❌ this line has no TAB between path and owner: $line"; exit 1 ;;
  esac
done < "$F"
while IFS=$'\t' read -r path owner; do
  want=$(awk -F'\t' -v p="$path" '$1 == p {print $2}' "$SANDBOX/.lm/expected.tsv")
  owner="$(echo "$owner" | sed 's/[[:space:]]*$//')"
  if [ -z "$want" ]; then
    echo "❌ '$path' is not one of the paths in suspects.txt (copy them exactly)"
    exit 1
  fi
  if [ "$owner" != "$want" ]; then
    if [ "$want" = "none" ]; then
      echo "❌ $path: no package owns this file, but you named '$owner'"
    elif [ "$owner" = "none" ]; then
      echo "❌ $path: a package does own this file, not 'none' (mind symlinked directories)"
    else
      echo "❌ $path: '$owner' is not the package that owns it"
    fi
    exit 1
  fi
done < "$F"
if [ "$(cut -f1 "$F" | sort -u | wc -l)" -ne 6 ]; then
  echo "❌ owners.tsv names the same path twice: all six suspects need a line"
  exit 1
fi
echo "✅ all six owners are right"
