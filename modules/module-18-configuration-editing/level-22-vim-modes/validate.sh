#!/bin/bash
# Diagnose the likely mistakes one by one, then compare with the expected file exactly.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s squid.conf ]; then
  echo "❌ squid.conf is missing or empty"
  exit 1
fi
if cmp -s squid.conf .lm-state/original.conf; then
  echo "❌ squid.conf has not been changed yet"
  exit 1
fi
if cmp -s squid.conf .lm-state/expected.conf; then
  echo "✅ all five changes are in squid.conf, and nothing else moved"
  exit 0
fi

left=$(awk '/^# LEGACY/ { f = 1; next } /^# END LEGACY/ { f = 0 } f && /^acl / { n++ } END { print n + 0 }' squid.conf)
if [ "$left" != 0 ]; then
  echo "❌ $left acl line(s) are still inside the # LEGACY block"
  exit 1
fi
outside=$(awk '/^# LEGACY/ { f = 1 } !f && /^acl / { n++ } /^# END LEGACY/ { f = 0 } END { print n + 0 }' squid.conf)
if [ "$outside" != "$(cat .lm-state/orig_acl_outside)" ]; then
  echo "❌ the number of acl lines outside the LEGACY block changed (was $(cat .lm-state/orig_acl_outside), now $outside): they had to stay"
  exit 1
fi
want=$(grep -c '^http_port 3129' .lm-state/expected.conf)
have=$(grep -c '^http_port 3129' squid.conf)
if [ "$have" != "$want" ]; then
  echo "❌ $have line(s) say http_port 3129, expected $want: only lines 120 to 180 change"
  exit 1
fi
if ! grep -q '^cache_dir ufs /var/spool/squid 2000 16 256$' squid.conf; then
  echo "❌ the cache_dir line is not joined into one line yet"
  exit 1
fi
if ! grep -q -x -F -f snippet.conf squid.conf || [ "$(grep -A1 -x -F '# ---- local overrides below ----' squid.conf | tail -1)" != "$(head -1 snippet.conf)" ]; then
  echo "❌ the contents of snippet.conf are not right after the '# local overrides below' marker"
  exit 1
fi
n=$(diff .lm-state/expected.conf squid.conf | grep -c '^[<>]')
first=$(diff .lm-state/expected.conf squid.conf | head -1)
echo "❌ squid.conf differs from the expected result in $n line(s) (first difference: diff says $first): something else was changed"
exit 1
