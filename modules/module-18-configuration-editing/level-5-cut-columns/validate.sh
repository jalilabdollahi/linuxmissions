#!/bin/bash
# keys.txt = defined names in order; signing_key.txt = full SIGNING_KEY value.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cmp -s prod.env .lm-state/prod.env; then
  echo "❌ prod.env was modified; the task is read-only, type 'reset' to restore it"
  exit 1
fi
for f in keys.txt signing_key.txt; do
  if [ ! -f "$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
done

want_key=$(cat .lm-state/signing_key)
got_key=$(tr -d '\r\n' < signing_key.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
if [ "$got_key" != "$want_key" ]; then
  if [ -z "$got_key" ]; then
    echo "❌ signing_key.txt is empty"
  elif [ "$got_key" = "SIGNING_KEY=$want_key" ]; then
    echo "❌ signing_key.txt contains the name too: write only the value"
  elif [ "${want_key#"$got_key"}" != "$want_key" ]; then
    echo "❌ signing_key.txt has ${#got_key} characters but the key has more: the value was cut off (it contains '=' itself)"
  else
    echo "❌ signing_key.txt is not the SIGNING_KEY value from prod.env"
  fi
  exit 1
fi

got=$(tr -d '\r' < keys.txt)
want=$(cat .lm-state/keys)
if [ "$got" = "$want" ]; then
  echo "✅ keys.txt lists the $(wc -l < .lm-state/keys | tr -d ' ') variable names and signing_key.txt has the whole key"
  exit 0
fi
if printf '%s\n' "$got" | grep -q '='; then
  echo "❌ keys.txt contains '=': it must list names only, no values"
elif printf '%s\n' "$got" | grep -q '^export'; then
  echo "❌ keys.txt still has lines with the 'export' prefix: the name is the word after it"
elif printf '%s\n' "$got" | grep -q '^[[:space:]]*#'; then
  echo "❌ keys.txt contains a comment line: commented-out settings are not defined"
elif printf '%s\n' "$got" | grep -q '^[[:space:]]*$'; then
  echo "❌ keys.txt contains a blank line"
elif [ "$(printf '%s\n' "$got" | wc -l)" != "$(wc -l < .lm-state/keys)" ]; then
  echo "❌ keys.txt has $(printf '%s\n' "$got" | wc -l | tr -d ' ') lines, expected $(wc -l < .lm-state/keys | tr -d ' ')"
else
  echo "❌ keys.txt has the right number of lines but the names or their order differ from prod.env"
fi
exit 1
