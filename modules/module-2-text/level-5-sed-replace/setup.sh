#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > config.conf <<'CONF'
# shop-api configuration
db_host=db.staging.internal
db_replicas=db-r1.staging.internal,db-r2.staging.internal
api_url=https://api.staging.internal:8443/v1
cache_hosts=cache1.staging.internal cache2.staging.internal cache3.staging.internal
smtp_relay=mail.staging.internal
search_url=http://search.staging.internal:9200
log_dir=/var/log/staging-internal/shop-api
metrics_prefix=staging_internal.shop_api
backup_target=staging.internal:/backups/shop-api
workers=8
CONF
