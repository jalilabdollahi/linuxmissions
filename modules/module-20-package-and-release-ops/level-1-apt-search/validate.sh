#!/bin/bash
# package.txt must name the CLI validator: one word, the real package.
SANDBOX="$1"
EXPECT="$(cat "$SANDBOX/.lm/tool" 2>/dev/null)"
F="$SANDBOX/package.txt"
if [ ! -f "$F" ]; then
  echo "❌ package.txt does not exist yet"
  exit 1
fi
LINES=$(grep -c . "$F")
WORDS=$(wc -w < "$F")
if [ "$LINES" -eq 0 ]; then
  echo "❌ package.txt is empty"
  exit 1
fi
if [ "$LINES" -ne 1 ] || [ "$WORDS" -ne 1 ]; then
  echo "❌ package.txt should hold just one package name on one line (it has $WORDS words on $LINES lines)"
  exit 1
fi
GOT="$(tr -d '[:space:]' < "$F")"
export APT_CONFIG="$SANDBOX/rootfs/etc/apt/apt.conf"
if ! /usr/bin/apt-cache show "$GOT" >/dev/null 2>&1; then
  echo "❌ '$GOT' is not a package in this mirror (write only the name, not the description)"
  exit 1
fi
if [ "$GOT" = "python3-$EXPECT" ]; then
  echo "❌ '$GOT' is the Python library, not the command-line tool"
  exit 1
fi
if [ "$GOT" = "lib$EXPECT-dev" ]; then
  echo "❌ '$GOT' is the header package for developers, not the tool people run"
  exit 1
fi
if [ "$GOT" = "$EXPECT-doc" ]; then
  echo "❌ '$GOT' is documentation, not the tool itself"
  exit 1
fi
if [ "$GOT" != "$EXPECT" ]; then
  echo "❌ '$GOT' is not the JSON Schema validator: read the descriptions with apt-cache show"
  exit 1
fi
echo "✅ $GOT is the command-line JSON Schema validator"
