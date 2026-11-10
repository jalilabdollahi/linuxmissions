#!/bin/bash
# proxy.conf == ours + the three vendor changes; no .rej/.orig left behind.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f proxy.conf ]; then
  echo "❌ proxy.conf is missing"
  exit 1
fi
if cmp -s proxy.conf .lm-state/ours.conf; then
  echo "❌ proxy.conf is still our original: the patch has not been applied yet"
  exit 1
fi
if cmp -s proxy.conf .lm-state/expected.conf; then
  leftover=$(find . -path ./.lm-state -prune -o \( -name '*.rej' -o -name '*.orig' \) -print | head -3 | tr '\n' ' ')
  if [ -n "$leftover" ]; then
    echo "❌ the merge is right but leftover patch files remain: $leftover"
    exit 1
  fi
  echo "✅ proxy.conf has all three vendor changes and every local edit; no .rej or .orig left"
  exit 0
fi
if ! grep -qx 'keepalive_timeout 30s;' proxy.conf; then
  echo "❌ the vendor's keepalive_timeout change is missing"
elif ! grep -qx 'proxy_read_timeout 120s;' proxy.conf; then
  echo "❌ the vendor's proxy_read_timeout change is missing"
elif ! grep -qx 'health_check_timeout 5s;' proxy.conf; then
  echo "❌ the vendor's health_check_timeout change is missing: one hunk was rejected, read the .rej file and apply it yourself"
elif ! grep -q 'health_check_interval 5s;  # local: faster checks' proxy.conf; then
  echo "❌ our local edit of health_check_interval was lost (the vendor does not change that line)"
elif ! grep -qx 'worker_connections 4096;' proxy.conf || ! grep -qx 'proxy_buffers 16 8k;' proxy.conf || ! grep -qx 'log_level info;' proxy.conf || ! grep -q 'OPS-881' proxy.conf; then
  echo "❌ one of our local edits (worker_connections, log_level, proxy_buffers or the OPS-881 comment) was lost"
else
  echo "❌ proxy.conf has all the changes but $(diff proxy.conf .lm-state/expected.conf | grep -c '^[<>]') other line(s) differ from the expected merge"
fi
exit 1
