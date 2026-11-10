#!/bin/bash
# Half a Vendor Patch: proxy.conf is the vendor stock file plus local edits.
# The patch (made against the stock file, with a/ and b/ prefixes) has three hunks.
# Hunks 1 and 2 apply with an offset. Hunk 3's innermost context line
# (health_check_interval) was edited locally, so even fuzz cannot place it
# and it ends up in proxy.conf.rej. The expected file is ours + all three changes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

cat > .lm-state/stock.conf <<'CONF'
# proxy.conf - reverse proxy settings (vendor stock)
listen 8080;
worker_connections 1024;
log_level notice;

# client side
client_header_timeout 10s;
client_body_timeout 10s;
keepalive_timeout 65s;
send_timeout 30s;

# upstream side
proxy_connect_timeout 5s;
proxy_send_timeout 30s;
# slow upstreams
proxy_read_timeout 60s;
proxy_next_upstream_timeout 0;

# buffers
proxy_buffer_size 8k;
proxy_buffers 8 8k;

# health
health_check_interval 10s;
health_check_timeout 3s;
health_check_fails 3;
health_check_passes 2;
health_check_uri /ping;
CONF

# The vendor's version of the file.
sed -e 's/^keepalive_timeout 65s;$/keepalive_timeout 30s;/' \
    -e 's/^proxy_read_timeout 60s;$/proxy_read_timeout 120s;/' \
    -e 's/^health_check_timeout 3s;$/health_check_timeout 5s;/' \
    .lm-state/stock.conf > .lm-state/vendor.conf

# Our file: stock plus local edits (one adds a line, so the hunks land at an offset).
sed -e '2a\
# local: tuned by ops, ticket OPS-881' \
    -e 's/^worker_connections 1024;$/worker_connections 4096;/' \
    -e 's/^log_level notice;$/log_level info;/' \
    -e 's/^proxy_buffers 8 8k;$/proxy_buffers 16 8k;/' \
    -e 's/^health_check_interval 10s;$/health_check_interval 5s;  # local: faster checks/' \
    .lm-state/stock.conf > proxy.conf
cp proxy.conf .lm-state/ours.conf

# Expected merge: our file plus the vendor's three changes.
sed -e 's/^keepalive_timeout 65s;$/keepalive_timeout 30s;/' \
    -e 's/^proxy_read_timeout 60s;$/proxy_read_timeout 120s;/' \
    -e 's/^health_check_timeout 3s;$/health_check_timeout 5s;/' \
    proxy.conf > .lm-state/expected.conf

diff -u --label a/proxy.conf --label b/proxy.conf .lm-state/stock.conf .lm-state/vendor.conf > fix-timeouts.patch
cp fix-timeouts.patch .lm-state/fix-timeouts.patch
