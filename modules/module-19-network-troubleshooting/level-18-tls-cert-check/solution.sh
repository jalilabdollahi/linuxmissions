#!/bin/bash
# Per service: expiry, chain to the root using only what the server sends,
# then the hostname against the SAN.
grep -v '^#' services.txt | while read -r svc host; do
  c=certs/$svc/fullchain.pem
  if ! openssl x509 -in "$c" -noout -checkend 0 >/dev/null; then st=EXPIRED
  elif ! openssl verify -CAfile certs/internal-root-ca.pem -untrusted "$c" "$c" >/dev/null 2>&1; then st=CHAIN
  elif ! openssl x509 -in "$c" -noout -checkhost "$host" | grep -q 'does match'; then st=NAME
  else st=OK
  fi
  printf '%s\t%s\n' "$svc" "$st"
done > tls-report.tsv
cat tls-report.tsv
