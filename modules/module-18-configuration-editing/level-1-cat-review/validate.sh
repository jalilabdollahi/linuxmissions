#!/bin/bash
# app.conf must equal the intended content byte for byte.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f app.conf ]; then
  echo "❌ app.conf is missing"
  exit 1
fi
if cmp -s app.conf .lm-state/expected.conf; then
  echo "✅ app.conf is clean: Unix endings, no trailing blanks, no hidden spaces, all settings kept"
  exit 0
fi
if grep -q $'\r' app.conf; then
  echo "❌ app.conf still has Windows (CR) line endings"
  exit 1
fi
if grep -q $'\xc2\xa0' app.conf; then
  echo "❌ app.conf still contains a non-breaking space (U+00A0)"
  exit 1
fi
if grep -q '[[:space:]]$' app.conf; then
  echo "❌ line $(grep -n '[[:space:]]$' app.conf | head -1 | cut -d: -f1) of app.conf still ends with whitespace"
  exit 1
fi
if ! grep -qx 'port = 8080' app.conf; then
  echo "❌ the port line is not 'port = 8080' any more: replace the hidden space, do not just delete it"
  exit 1
fi
echo "❌ the hidden characters are gone, but app.conf no longer matches the original settings ($(diff app.conf .lm-state/expected.conf | grep -c '^[<>]') differing lines)"
exit 1
