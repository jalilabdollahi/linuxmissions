#!/bin/bash
# password.txt: random password on line 1 and a note on line 2.
# tls.crt: a PEM-shaped file of about 3 KB (random payload, 64-column lines).
# logo.png: PNG signature followed by random bytes (contains NULs and high bytes).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
pw=$(LC_ALL=C tr -dc 'A-Za-z0-9!#%+=' < /dev/urandom | head -c $((14 + RANDOM % 6)))
printf '%s\n# rotated by ops, do not commit\n' "$pw" > password.txt
{
  echo "-----BEGIN CERTIFICATE-----"
  head -c $((2100 + RANDOM % 300)) /dev/urandom | base64 -w64
  echo "-----END CERTIFICATE-----"
} > tls.crt
{ printf '\x89PNG\r\n\x1a\n'; head -c $((1500 + RANDOM % 600)) /dev/urandom; } > logo.png
cp password.txt tls.crt logo.png .lm-state/
