#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

ORIGINAL='# shop-api configuration
db_host=db.staging.internal
db_replicas=db-r1.staging.internal,db-r2.staging.internal
api_url=https://api.staging.internal:8443/v1
cache_hosts=cache1.staging.internal cache2.staging.internal cache3.staging.internal
smtp_relay=mail.staging.internal
search_url=http://search.staging.internal:9200
log_dir=/var/log/staging-internal/shop-api
metrics_prefix=staging_internal.shop_api
backup_target=staging.internal:/backups/shop-api
workers=8'

EXPECTED='# shop-api configuration
db_host=db.prod.internal
db_replicas=db-r1.prod.internal,db-r2.prod.internal
api_url=https://api.prod.internal:8443/v1
cache_hosts=cache1.prod.internal cache2.prod.internal cache3.prod.internal
smtp_relay=mail.prod.internal
search_url=http://search.prod.internal:9200
log_dir=/var/log/staging-internal/shop-api
metrics_prefix=staging_internal.shop_api
backup_target=prod.internal:/backups/shop-api
workers=8'

if [ ! -f config.conf ] || [ "$(cat config.conf)" != "$ORIGINAL" ]; then
  echo "❌ config.conf was modified; it must stay the staging version. Type 'reset' and write the result to a new file"
  exit 1
fi
if [ ! -f config.prod.conf ]; then
  echo "❌ config.prod.conf does not exist yet"
  exit 1
fi
GOT=$(tr -d '\r' < config.prod.conf)
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ config.prod.conf points at prod.internal and nothing else changed"
  exit 0
fi

left=$(printf '%s\n' "$GOT" | grep -c 'staging\.internal')
if [ "$left" -gt 0 ]; then
  echo "❌ config.prod.conf still contains staging.internal on $left line(s): some lines have it more than once"
elif ! printf '%s\n' "$GOT" | grep -q 'staging-internal' || ! printf '%s\n' "$GOT" | grep -q 'staging_internal'; then
  echo "❌ text that only looks like the hostname was replaced too (in a sed pattern, . matches any character)"
else
  line=$(diff <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$GOT") | grep -m1 -E '^[0-9]' | sed 's/[^0-9].*//')
  echo "❌ config.prod.conf differs from what is expected around line ${line:-?}; only the hostname may change"
fi
exit 1
