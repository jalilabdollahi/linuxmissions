#!/bin/bash
# The Race Before chmod. issue-cert.sh creates the key with the caller's umask
# and only afterwards chmods it. The validator replaces chmod with a no-op on
# PATH and runs the script under umask 000, 022 and 077: a key that only
# becomes private through chmod comes out world-readable, so the fix has to
# make the file private at creation time (umask in a subshell, or install -m).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf issue-cert.sh certs; mkdir -p .lm-state
cat > issue-cert.sh <<'SCRIPT'
#!/bin/bash
# issue-cert.sh NAME - create a private key, a request and a certificate.
# Files go to $CERT_DIR/NAME/ (default: certs/NAME/).
set -e
name=${1:?usage: issue-cert.sh NAME}
out=${CERT_DIR:-certs}

echo "Issuing certificate for $name"
mkdir -p "$out/$name"
key="$out/$name/$name.key"

# private key (demo material, not a real key)
{
  echo "-----BEGIN PRIVATE KEY-----"
  head -c 96 /dev/urandom | base64
  echo "-----END PRIVATE KEY-----"
} > "$key"
chmod 600 "$key"

# request and certificate are public
echo "request for $name" > "$out/$name/$name.csr"
echo "certificate for $name valid 90 days" > "$out/$name/$name.crt"

echo "  key: $key"
echo "  csr: $out/$name/$name.csr"
echo "  crt: $out/$name/$name.crt"
SCRIPT
chmod 755 issue-cert.sh
cksum < issue-cert.sh > .lm-state/orig-sum
