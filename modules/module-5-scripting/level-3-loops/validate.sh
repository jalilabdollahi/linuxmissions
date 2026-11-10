#!/bin/bash
# Runs rename.sh on scratch copies (never on the player's incoming/) and
# compares the resulting directory listing and file contents.
SANDBOX="$1"
SCRIPT="$SANDBOX/rename.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ rename.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# Test 1: a drop folder whose own name has a space.
D="$WORK/drop zone"
mkdir -p "$D/sub"
echo "one"    > "$D/a.txt"
echo "two"    > "$D/b.txt"
echo "three"  > "$D/year end report.txt"
echo "four"   > "$D/readme.md"
echo "five"   > "$D/data.txt.gz"
echo "six"    > "$D/sub/deep.txt"

(cd "$WORK" && $LIMIT bash "$SCRIPT" "$D" </dev/null >/dev/null 2>&1)

actual="$(cd "$D" && find . | LC_ALL=C sort | tr '\n' '|')"
expected="$(printf '%s\n' . ./a.bak ./b.bak ./data.txt.gz ./readme.md ./sub ./sub/deep.txt './year end report.bak' | LC_ALL=C sort | tr '\n' '|')"

if [ -e "$D/year end report.txt" ] || [ -e "$D/a.txt" ]; then
  echo "❌ after bash rename.sh \"drop zone\", some .txt files were not renamed (does it work when names or the folder contain spaces?)"
  exit 1
fi
if [ "$actual" != "$expected" ]; then
  echo "❌ after bash rename.sh \"drop zone\" the folder holds: $(echo "$actual" | tr '|' ' ')"
  echo "   expected: $(echo "$expected" | tr '|' ' ')"
  exit 1
fi
if [ "$(cat "$D/year end report.bak")" != "three" ] || [ "$(cat "$D/a.bak")" != "one" ]; then
  echo "❌ the renamed files do not have their original contents any more"
  exit 1
fi

# Test 2: nothing to do.
E="$WORK/empty"
mkdir -p "$E"
echo "x" > "$E/only.md"
err="$(cd "$WORK" && $LIMIT bash "$SCRIPT" "$E" 2>&1 >/dev/null </dev/null)"
code=$?
if [ "$(cd "$E" && ls -A)" != "only.md" ]; then
  echo "❌ on a folder without .txt files, rename.sh created or changed files: $(cd "$E" && ls -A | tr '\n' ' ')"
  exit 1
fi
if [ -n "$err" ] || [ "$code" != "0" ]; then
  echo "❌ on a folder without .txt files, rename.sh failed (status $code): ${err%%$'\n'*}"
  exit 1
fi

echo "✅ rename.sh renames every .txt file in the folder and leaves the rest alone"
exit 0
