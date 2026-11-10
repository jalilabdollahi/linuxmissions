#!/bin/bash
# Runs check_file.sh against test paths (some with spaces) and checks the
# printed word and the exit status for each one.
SANDBOX="$1"
SCRIPT="$SANDBOX/check_file.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ check_file.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
echo "x" > "$WORK/plain.txt"
echo "x" > "$WORK/annual report.txt"
mkdir -p "$WORK/logs" "$WORK/old photos"

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# expect PATH WORD STATUS
expect() {
  local path="$1" word="$2" status="$3" out code
  out="$(cd "$WORK" && $LIMIT bash "$SCRIPT" "$path" </dev/null 2>/dev/null | tr -d '\r')"
  code="$(cd "$WORK" && $LIMIT bash "$SCRIPT" "$path" </dev/null >/dev/null 2>&1; echo $?)"
  if [ "$out" != "$word" ]; then
    echo "❌ bash check_file.sh \"$path\" printed '$out', expected '$word'"
    exit 1
  fi
  if [ "$status" = "0" ] && [ "$code" != "0" ]; then
    echo "❌ bash check_file.sh \"$path\" printed $word but exited with status $code, expected 0"
    exit 1
  fi
  if [ "$status" = "1" ] && [ "$code" != "1" ]; then
    echo "❌ bash check_file.sh \"$path\" printed MISSING but exited with status $code, expected 1"
    exit 1
  fi
}

expect "plain.txt" FILE 0
expect "logs" DIR 0
expect "nothing-here.txt" MISSING 1
expect "annual report.txt" FILE 0
expect "old photos" DIR 0
expect "lost and found" MISSING 1
expect "$WORK/plain.txt" FILE 0

echo "✅ check_file.sh tells files, directories and missing paths apart"
exit 0
