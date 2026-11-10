#!/bin/bash
# Make the key private from its first byte: a subshell with umask 077 around the
# mkdir and the key creation (the caller's umask is untouched).
cat > issue-cert.sh <<'SCRIPT'
#!/bin/bash
# issue-cert.sh NAME - create a private key, a request and a certificate.
# Files go to $CERT_DIR/NAME/ (default: certs/NAME/).
set -e
name=${1:?usage: issue-cert.sh NAME}
out=${CERT_DIR:-certs}

echo "Issuing certificate for $name"
key="$out/$name/$name.key"

# private key (demo material, not a real key)
(
  umask 077
  mkdir -p "$out/$name"
  {
    echo "-----BEGIN PRIVATE KEY-----"
    head -c 96 /dev/urandom | base64
    echo "-----END PRIVATE KEY-----"
  } > "$key"
)

# request and certificate are public
echo "request for $name" > "$out/$name/$name.csr"
echo "certificate for $name valid 90 days" > "$out/$name/$name.crt"

echo "  key: $key"
echo "  csr: $out/$name/$name.csr"
echo "  crt: $out/$name/$name.crt"
SCRIPT
./issue-cert.sh demo && ls -l certs/demo && rm -rf certs
