#!/bin/bash
# Runs greet.sh with several names (and none) and compares the exact output.
SANDBOX="$1"
SCRIPT="$SANDBOX/greet.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ greet.sh is missing (type reset to get it back)"
  exit 1
fi

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

greet() {
  (cd "$SANDBOX" && $LIMIT bash "$SCRIPT" "$@" </dev/null 2>/dev/null | tr -d '\r')
}

got="$(greet World)"
if [ "$got" != "Hello, World!" ]; then
  echo "❌ bash greet.sh World printed '$got', expected 'Hello, World!'"
  exit 1
fi

got="$(greet Linus)"
if [ "$got" != "Hello, Linus!" ]; then
  echo "❌ bash greet.sh Linus printed '$got', expected 'Hello, Linus!'"
  exit 1
fi

got="$(greet "Ada Lovelace")"
if [ "$got" != "Hello, Ada Lovelace!" ]; then
  echo "❌ bash greet.sh \"Ada Lovelace\" printed '$got', expected 'Hello, Ada Lovelace!'"
  exit 1
fi

got="$(greet)"
if [ "$got" != "Hello, stranger!" ]; then
  echo "❌ bash greet.sh with no name printed '$got', expected 'Hello, stranger!'"
  exit 1
fi

echo "✅ greet.sh greets people by name and falls back to 'stranger'"
exit 0
