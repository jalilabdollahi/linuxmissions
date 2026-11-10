#!/bin/bash
# $1 = sandbox path
# An internal PKI (root -> intermediate -> leaves) built with openssl at
# setup. Five services get one of these, shuffled per setup:
#   OK        full chain, SAN = hostname
#   OK        full chain, wildcard cert (*.corp.example): CN differs from the
#             hostname, but the SAN matches (naive CN check says "wrong")
#   EXPIRED   full chain, right name, notAfter in 2025 (fixed dates)
#   NAME      CN = hostname but the SAN list doesn't contain it
#   CHAIN     leaf only, intermediate missing
# Valid certs end in 2045, so the answer never changes with the clock.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }

services=(portal git grafana vault wiki)
problems=(OK WILDCARD EXPIRED NAME CHAIN)
mapfile -t problems < <(printf '%s\n' "${problems[@]}" | shuf)

PKI="$SANDBOX/.pki"
mkdir -p "$PKI/newcerts" certs
: > "$PKI/index.txt"
echo 1000 > "$PKI/serial"
cat > "$PKI/ca.cnf" <<'EOF'
[ ca ]
default_ca = sub
[ sub ]
dir = .
database = $dir/index.txt
new_certs_dir = $dir/newcerts
serial = $dir/serial
default_md = sha256
policy = anything
unique_subject = no
email_in_dn = no
[ anything ]
commonName = supplied
organizationName = optional
EOF
cd "$PKI" || exit 1
key() { openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$1" 2>/dev/null; }

key root.key
openssl req -x509 -new -key root.key -days 9000 -subj "/O=Corp Example/CN=Corp Example Root CA R2" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" -out root.pem 2>/dev/null
key inter.key
openssl req -new -key inter.key -subj "/O=Corp Example/CN=Corp Example Issuing CA 3" -out inter.csr 2>/dev/null
printf 'basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n' > inter.ext
openssl ca -batch -config ca.cnf -cert root.pem -keyfile root.key -in inter.csr -out inter.pem -notext \
  -startdate 20240101000000Z -enddate 20460101000000Z -extfile inter.ext >/dev/null 2>&1

leaf() {  # name cn san startdate enddate
  key "$1.key"
  openssl req -new -key "$1.key" -subj "/O=Corp Example/CN=$2" -out "$1.csr" 2>/dev/null
  printf 'basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=%s\n' "$3" > "$1.ext"
  openssl ca -batch -config ca.cnf -cert inter.pem -keyfile inter.key -in "$1.csr" -out "$1.pem" -notext \
    -startdate "$4" -enddate "$5" -extfile "$1.ext" >/dev/null 2>&1
}

for i in "${!services[@]}"; do
  s=${services[$i]}
  host="$s.corp.example"
  case ${problems[$i]} in
    OK)       leaf "$s" "$host" "DNS:$host" 20251101000000Z 20451101000000Z ;;
    WILDCARD) leaf "$s" "*.corp.example" "DNS:*.corp.example,DNS:corp.example" 20251101000000Z 20451101000000Z ;;
    EXPIRED)  leaf "$s" "$host" "DNS:$host" 20231101000000Z 20241101000000Z ;;
    NAME)     leaf "$s" "$host" "DNS:$s-new.corp.example,DNS:$s.corp.local" 20251101000000Z 20451101000000Z ;;
    CHAIN)    leaf "$s" "$host" "DNS:$host,DNS:$s" 20251101000000Z 20451101000000Z ;;
  esac
  [ -s "$s.pem" ] || { echo "could not create the certificate for $s" >&2; exit 1; }
  mkdir -p "$SANDBOX/certs/$s"
  if [ "${problems[$i]}" = CHAIN ]; then
    cp "$s.pem" "$SANDBOX/certs/$s/fullchain.pem"
  else
    cat "$s.pem" inter.pem > "$SANDBOX/certs/$s/fullchain.pem"
  fi
done
cp root.pem "$SANDBOX/certs/internal-root-ca.pem"
cd "$SANDBOX" && rm -rf "$PKI"

printf '%s\n' "# service   hostname clients use" > services.txt
for s in "${services[@]}"; do printf '%-10s  %s\n' "$s" "$s.corp.example" >> services.txt; done

cat > TICKET.txt <<'EOF'
SEC-640  TLS renewals: browsers still complain

Last week we renewed the certificates of the five internal web services.
Some of them still get certificate warnings in browsers, and nobody checked
which and why.

certs/<service>/fullchain.pem is exactly what each server sends (its
certificate followed by any intermediate). certs/internal-root-ca.pem is our
root CA, which every client trusts. services.txt has the hostname clients
use for each service.

Write tls-report.tsv: one line per service, "service<TAB>status", where
status is one of
  OK       browsers accept it
  EXPIRED  the certificate is no longer valid
  NAME     the certificate is not valid for the hostname clients use
  CHAIN    browsers can't build a chain to our root (intermediate missing)
Each service has at most one problem.
EOF
