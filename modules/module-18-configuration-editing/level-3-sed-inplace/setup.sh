#!/bin/bash
# Staging Moves Over: [staging] and [production] both have "port = 8080".
# The staging section also has a comment that mentions 8080, and so does [common],
# so a blind s/8080/9080/ changes four more things than it should.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

cat > services.conf <<'CONF'
# services.conf - listener settings per environment
# NB: 8080 is the default port of the app server

[common]
log_dir = /var/log/svc
pid_dir = /run/svc
# metrics are scraped on 8081, health checks on 8080

[production]
host = prod-app-01.internal
port = 8080
workers = 16
tls = on

[staging]
host = stage-app-01.internal
# port = 8080 collided with the old jenkins agent
port = 8080
workers = 2
tls = off
admin_port = 18080

[dev]
host = localhost
port = 8080
workers = 1
CONF
cp services.conf .lm-state/original.conf

# Expected result: only the real staging port line changes.
awk '/^\[/ { sec = $0 } sec == "[staging]" && $0 == "port = 8080" { $0 = "port = 9080" } { print }' \
  services.conf > .lm-state/expected.conf
