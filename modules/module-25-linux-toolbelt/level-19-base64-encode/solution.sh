#!/bin/bash
# base64 -w0 = no line wrapping; tr -d '\n' removes the newline that head keeps,
# so it is not encoded into the password.
pw=$(head -n 1 password.txt | tr -d '\n' | base64 -w0)
crt=$(base64 -w0 tls.crt)
logo=$(base64 -w0 logo.png)
{
  echo "apiVersion: v1"
  echo "kind: Secret"
  echo "metadata:"
  echo "  name: app-secrets"
  echo "type: Opaque"
  echo "data:"
  echo "  db-password: $pw"
  echo "  tls.crt: $crt"
  echo "  logo.png: $logo"
} > secret.yaml
head -c 300 secret.yaml
