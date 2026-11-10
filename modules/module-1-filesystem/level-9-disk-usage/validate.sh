#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1
EXPECTED="home/bob/.local/share/Trash/files/old-vm.img"

if [ ! -f "$EXPECTED" ]; then
  echo "❌ some files were deleted; the task is only to find the largest one. Type 'reset'"
  exit 1
fi
if [ ! -f biggest.txt ]; then
  echo "❌ biggest.txt does not exist in the sandbox root"
  exit 1
fi

REAL=$(pwd -P)
ANSWER=$(tr -d '\r' < biggest.txt |
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
  awk -v a="${SANDBOX%/}/" -v b="$REAL/" '
    index($0, a) == 1 { $0 = substr($0, length(a) + 1) }
    index($0, b) == 1 { $0 = substr($0, length(b) + 1) }
    { sub(/^\.\//, "") }
    length($0) > 0')

lines=$(printf '%s\n' "$ANSWER" | grep -c .)
if [ "$lines" -ne 1 ]; then
  echo "❌ biggest.txt should contain exactly one path, it has $lines"
  exit 1
fi
if [ "$ANSWER" = "$EXPECTED" ]; then
  echo "✅ biggest.txt names the largest file"
  exit 0
fi
if [ -d "$ANSWER" ]; then
  echo "❌ '$ANSWER' is a directory; the task asks for the largest single file"
elif [ -f "$ANSWER" ]; then
  echo "❌ '$ANSWER' is big, but it is not the largest file"
else
  echo "❌ '$ANSWER' is not a file in the sandbox (write just the path, e.g. ./dir/file)"
fi
exit 1
