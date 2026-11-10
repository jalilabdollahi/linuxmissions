#!/bin/bash
# Tenant Onboarding: tenants.txt is a hand-written ticket list with comments,
# indented comments, blank lines and tenant names containing spaces, an
# apostrophe and an ampersand. Each tenant needs tenants/<name>/app.conf.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p template tenants

pool=(globex initech "umbrella labs" hooli "stark industries" "wayne & sons" soylent
      "vandelay imports" cyberdyne "pied piper" tyrell wonka "duff beer" "bluth company")
# Pick 8 tenants from the pool (random each setup), plus the two the ticket is about.
picked=()
while [ ${#picked[@]} -lt 8 ]; do
  cand="${pool[$(( RANDOM % ${#pool[@]} ))]}"
  dup=0
  for p in "${picked[@]}"; do [ "$p" = "$cand" ] && dup=1; done
  [ $dup -eq 0 ] && picked+=("$cand")
done
eu=("acme corp" "${picked[@]:0:4}")
us=("${picked[@]:4:2}" "o'reilly media" "${picked[@]:6:2}")

{
  echo "# OPS-4521  tenants to onboard this sprint, one per line"
  echo "# (comments start with #, blank lines are just for readability)"
  echo ""
  echo "# --- EU region ---"
  printf '%s\n' "${eu[@]:0:3}"
  echo "   # paused: massive dynamic (unpaid invoice), do not create yet"
  printf '%s\n' "${eu[@]:3}"
  echo "  "
  echo "# --- US region ---"
  printf '%s\n' "${us[@]}"
  echo ""
} > tenants.txt
cksum < tenants.txt > .tenants.sum

secret=$(printf '%04x%04x%04x' $RANDOM $RANDOM $RANDOM)
cat > template/app.conf <<EOF
# app.conf - per-tenant settings (identical for every tenant at onboarding)
[server]
listen      = 0.0.0.0:8080
workers     = 4

[storage]
bucket_prefix = tenants
quota_gb      = 50

[auth]
session_ttl   = 3600
signing_key   = $secret
EOF
