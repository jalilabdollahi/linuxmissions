#!/bin/bash
# Run issue-cert.sh (as a subprocess) under umask 000, 022 and 077 with chmod
# replaced by a no-op: the key must be 600 and every new directory 700 in all
# three cases, the output must match the original text, key/csr/crt must exist,
# The script must have been edited.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
[ -f issue-cert.sh ] || { echo "❌ issue-cert.sh is missing"; exit 1; }
if [ "$(cksum < issue-cert.sh)" = "$(cat .lm-state/orig-sum 2>/dev/null)" ]; then
  echo "❌ issue-cert.sh is still the original script: the key is created first and secured afterwards"; exit 1
fi

T=$(mktemp -d "$SANDBOX/.lm-state/run.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/shim"
printf '#!/bin/sh\nexit 0\n' > "$T/shim/chmod"; chmod 755 "$T/shim/chmod"

for um in 000 022 077; do
  rm -rf "$T/out"
  got=$( cd "$T" && umask $um && PATH="$T/shim:$PATH" CERT_DIR="$T/out" bash "$SANDBOX/issue-cert.sh" web01 2>&1 )
  rc=$?
  if [ $rc -ne 0 ]; then echo "❌ issue-cert.sh fails when run with umask $um: ${got##*$'\n'}"; exit 1; fi
  exp="Issuing certificate for web01
  key: $T/out/web01/web01.key
  csr: $T/out/web01/web01.csr
  crt: $T/out/web01/web01.crt"
  if [ "$got" != "$exp" ]; then echo "❌ the script's output changed (umask $um): it must print exactly what it printed before"; exit 1; fi
  key="$T/out/web01/web01.key"
  if [ ! -s "$key" ] || ! grep -q 'BEGIN PRIVATE KEY' "$key"; then echo "❌ no usable private key was produced"; exit 1; fi
  [ -s "$T/out/web01/web01.csr" ] && [ -s "$T/out/web01/web01.crt" ] || { echo "❌ the request or the certificate is missing"; exit 1; }
  m=$(mode "$key")
  if [ "$m" != 600 ]; then
    echo "❌ with umask $um the key is created with mode $m: it must be private from the first moment, not after a later chmod"; exit 1
  fi
  for d in "$T/out" "$T/out/web01"; do
    m=$(mode "$d")
    if [ "$m" != 700 ]; then echo "❌ with umask $um the new directory ${d#$T/} has mode $m, but the key's folders must be private to the owner too"; exit 1; fi
  done
done

echo "✅ the key and its folders are private from the moment they are created, under every umask"
exit 0
