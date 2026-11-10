#!/bin/bash
# Snapshot Name: VERSION ends in \r\n, so "$(cat VERSION)" keeps an invisible \r.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p config/routes config/tls backups

hex() { printf '%04x%04x' $RANDOM $RANDOM; }
printf '%s\r\n' "5.$(( RANDOM % 12 )).$(( RANDOM % 40 ))+build.$(hex | cut -c1-7)" > VERSION

cat > config/gateway.yaml <<EOF
listen: 0.0.0.0:8443
workers: $(( RANDOM % 8 + 2 ))
upstream_timeout_ms: $(( RANDOM % 4000 + 1000 ))
access_log: /var/log/gateway/access.log
EOF
for r in billing search users; do
  printf 'route: /%s\nupstream: http://%s.internal:%d\nretries: %d\n' "$r" "$r" $(( RANDOM % 1000 + 9000 )) $(( RANDOM % 4 )) > "config/routes/$r.yaml"
done
printf -- '-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----\n' "$(hex)$(hex)$(hex)$(hex)" > config/tls/gateway.crt
printf 'ttl=%d\nsalt=%s\n' $(( RANDOM % 600 + 60 )) "$(hex)" > config/.cache-salt
