#!/bin/bash
# Compare impact.txt with the removals the real apt-get -s remove plans for libold1.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export LC_ALL=C
ROOT="$SANDBOX/rootfs"
st=$(dpkg-query --root="$ROOT" -W -f='${db:Status-Abbrev}' libold1 2>/dev/null)
if [ "$st" != "ii " ]; then
  echo "❌ libold1 is no longer installed: the job is to report the impact, not to remove it (reset the level and try again)"
  exit 1
fi
if [ ! -s impact.txt ]; then
  echo "❌ impact.txt does not exist yet (or is empty)"
  exit 1
fi
APT_CONFIG="$ROOT/etc/apt/apt.conf" /usr/bin/apt-get -s remove libold1 2>/dev/null | sed -n 's/^Remv \([^ ]*\).*/\1/p' | grep -vx libold1 | sort -u > .lm/want.txt
if [ ! -s .lm/want.txt ]; then
  echo "❌ the validator could not compute the expected removals (apt-get -s remove libold1 gave nothing)"
  exit 1
fi
if grep -qvE '^[a-z0-9][a-z0-9+.-]*$' impact.txt; then
  echo "❌ impact.txt must hold plain package names, one per line (no versions, arrows or spaces)"
  exit 1
fi
if grep -qx libold1 impact.txt; then
  echo "❌ impact.txt lists libold1 itself: list only the packages that go with it"
  exit 1
fi
sort -u impact.txt > .lm/got.txt
miss=$(comm -13 .lm/got.txt .lm/want.txt | wc -l)
extra=$(comm -23 .lm/got.txt .lm/want.txt | wc -l)
if [ "$miss" -ne 0 ] && [ "$extra" -eq 0 ]; then
  echo "❌ impact.txt is missing $miss package(s) that would be removed (follow the chain: dependents of dependents)"
  exit 1
fi
if [ "$extra" -ne 0 ]; then
  echo "❌ impact.txt lists $extra package(s) that would not be removed (a Recommends or Suggests, an alternative that is still satisfied, or a package that is not installed does not go)${miss:+; and $miss real one(s) are missing}"
  exit 1
fi
echo "✅ impact.txt lists exactly the $(wc -l < .lm/got.txt) packages that go with libold1"
