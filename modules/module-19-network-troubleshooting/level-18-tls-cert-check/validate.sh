#!/bin/bash
# $1 = sandbox path
# Works out each service's status with openssl itself: expiry (-checkend 0),
# chain (verify against the root with only what the server sends) and the
# hostname (-checkhost, which uses the SAN). Then compares tls-report.tsv.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
ROOT=certs/internal-root-ca.pem
REPORT=tls-report.tsv

[ -f "$REPORT" ] || { echo "❌ $REPORT does not exist yet"; exit 1; }

declare -A want
while read -r svc host; do
  case $svc in ''|\#*) continue ;; esac
  chain="certs/$svc/fullchain.pem"
  [ -f "$chain" ] && [ -f "$ROOT" ] || { echo "❌ certs/ was changed; type 'reset' to get it back"; exit 1; }
  if ! openssl x509 -in "$chain" -noout -checkend 0 >/dev/null 2>&1; then
    want[$svc]=EXPIRED
  elif ! openssl verify -CAfile "$ROOT" -untrusted "$chain" "$chain" >/dev/null 2>&1; then
    want[$svc]=CHAIN
  elif ! openssl x509 -in "$chain" -noout -checkhost "$host" 2>/dev/null | grep -q 'does match'; then
    want[$svc]=NAME
  else
    want[$svc]=OK
  fi
done < services.txt

declare -A got
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'}
  [ -z "${line//[[:space:]]/}" ] && continue
  read -r svc status extra <<< "$line"
  if [ -z "${want[$svc]+x}" ]; then
    echo "❌ $REPORT: '$svc' is not one of the services in services.txt"; exit 1
  fi
  if [ -n "$extra" ] || [ -z "$status" ]; then
    echo "❌ $REPORT: the line for $svc should be just: service<TAB>status"; exit 1
  fi
  [ -n "${got[$svc]+x}" ] && { echo "❌ $REPORT has two lines for $svc"; exit 1; }
  got[$svc]=$status
done < "$REPORT"

for svc in $(printf '%s\n' "${!want[@]}" | sort); do
  [ -n "${got[$svc]+x}" ] || { echo "❌ $REPORT has no line for $svc"; exit 1; }
done
wrong=0
for svc in $(printf '%s\n' "${!want[@]}" | sort); do
  w=${want[$svc]} g=${got[$svc]}
  case $g in OK|EXPIRED|NAME|CHAIN) ;; *) echo "❌ $REPORT: '$g' for $svc is not one of OK, EXPIRED, NAME, CHAIN"; exit 1 ;; esac
  [ "$g" = "$w" ] && continue
  case $g/$w in
    NAME/OK)  echo "❌ $svc: browsers ignore the CN when a certificate has a subjectAltName; which names does its SAN cover?" ;;
    OK/NAME)  echo "❌ $svc: the CN looks right, but browsers only check the subjectAltName list" ;;
    */CHAIN)  echo "❌ $svc: can a browser get from its certificate to our root with only what is in its fullchain.pem?" ;;
    */EXPIRED) echo "❌ $svc: look at its validity dates" ;;
    *)        echo "❌ $svc is not $g" ;;
  esac
  exit 1
done
echo "✅ tls-report.tsv is right for all ${#want[@]} services"
