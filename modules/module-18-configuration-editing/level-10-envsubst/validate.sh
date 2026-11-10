#!/bin/bash
# nginx.conf = template with only the two app variables replaced.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cmp -s nginx.conf.tmpl .lm-state/tmpl; then
  echo "❌ nginx.conf.tmpl was modified: render into nginx.conf and keep the template as it is"
  exit 1
fi
if [ ! -f nginx.conf ]; then
  echo "❌ nginx.conf does not exist yet"
  exit 1
fi
if cmp -s nginx.conf .lm-state/expected.conf; then
  echo "✅ nginx.conf is rendered: app values filled in, nginx variables left for nginx"
  exit 0
fi
if cmp -s nginx.conf nginx.conf.tmpl; then
  echo "❌ nginx.conf is just a copy of the template: the app placeholders are still there"
  exit 1
fi
for v in host remote_addr request_uri http_upgrade scheme connection_upgrade; do
  if [ "$(grep -c "\$$v" nginx.conf)" != "$(grep -c "\$$v" nginx.conf.tmpl)" ]; then
    echo "❌ the nginx variable \$$v was changed: only \$APP_HOST and \${APP_PORT} may be replaced"
    exit 1
  fi
done
if grep -q 'APP_HOST\|APP_PORT' nginx.conf; then
  echo "❌ a placeholder (APP_HOST or APP_PORT) is still unreplaced in nginx.conf"
elif grep -qE 'server +:|server_name *;|server +[^ ]*:( |;)|:\$request_uri|http://[^:]*:' nginx.conf && ! grep -q "$(sed -n 's/^APP_HOST=//p' .lm-state/deploy.env)" nginx.conf; then
  echo "❌ the app values came out empty: envsubst only sees exported variables"
else
  echo "❌ nginx.conf differs from the expected rendering ($(diff nginx.conf .lm-state/expected.conf | grep -c '^[<>]') lines)"
fi
exit 1
