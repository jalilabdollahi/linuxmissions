#!/bin/bash
# services.conf == expected, services.conf.bak == original, one changed line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f services.conf.bak ]; then
  echo "❌ services.conf.bak does not exist: keep a backup of the original while editing"
  exit 1
fi
if ! cmp -s services.conf.bak .lm-state/original.conf; then
  echo "❌ services.conf.bak is not the original file (was the backup made before the edit?)"
  exit 1
fi
if cmp -s services.conf .lm-state/original.conf; then
  echo "❌ services.conf has not been changed yet"
  exit 1
fi
if cmp -s services.conf .lm-state/expected.conf; then
  echo "✅ staging now listens on 9080; production, comments and the backup are untouched"
  exit 0
fi
sec=$(awk '/^\[/ { sec = $0 } $0 == "port = 8080" { print sec }' services.conf | tr '\n' ' ')
if ! grep -qx 'port = 8080' services.conf || [ "$(awk '/^\[/ { sec = $0 } $0 == "port = 9080" { print sec }' services.conf)" != "[staging]" ]; then
  if ! awk '/^\[/ { sec = $0 } sec == "[production]" && $0 == "port = 8080" { f = 1 } END { exit !f }' services.conf; then
    echo "❌ [production] no longer has port = 8080: only staging moves"
    exit 1
  fi
  echo "❌ the [staging] port line is not 'port = 9080' yet"
  exit 1
fi
n=$(diff services.conf .lm-state/original.conf | grep -c '^<')
echo "❌ $n lines changed, but only one should: the port setting of [staging] (comments and other keys must keep 8080)"
exit 1
