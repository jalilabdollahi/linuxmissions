#!/bin/bash
# With the real apt-cache: ripgrep's candidate is the backports build, every other
# package's candidate is the main archive's, the shipped nosnap pin still works,
# and a simulated upgrade would change ripgrep only.
SANDBOX="$1"
ROOT="$SANDBOX/rootfs"
export APT_CONFIG="$ROOT/etc/apt/apt.conf"
PD="$ROOT/etc/apt/preferences.d"
cand() { /usr/bin/apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}'; }
WANT="$(cat "$SANDBOX/.lm/want")"

if ! grep -q 'Package: snapd' "$PD/nosnap.pref" 2>/dev/null || [ "$(cand snapd)" != "(none)" ]; then
  echo "❌ the existing nosnap.pref pin was changed or removed: leave other preferences alone"
  exit 1
fi
for pair in "fd-find 9.0.0-1" "bat 0.24.0-1" "libpcre2-8-0 10.42-4"; do
  set -- $pair
  if [ "$(cand "$1")" != "$2" ]; then
    echo "❌ $1 would now come from backports ($(cand "$1")); the pin is too broad"
    exit 1
  fi
done
GOT="$(cand ripgrep)"
if [ "$GOT" != "$WANT" ]; then
  HINT=""
  for f in "$PD"/*; do
    [ "$(basename "$f")" = nosnap.pref ] && continue
    [ -f "$f" ] || continue
    if grep -qi 'ripgrep' "$f" 2>/dev/null; then
      base="$(basename "$f")"
      if [[ "$base" == *.* && "$base" != *.pref ]]; then
        HINT=" ($base is ignored by apt: only names without an extension or ending in .pref are read)"
      elif grep -qE 'n=noble-backports' "$f"; then
        HINT=" (the backports Release file's Codename is noble; its Suite, the a= field, is noble-backports)"
      elif grep -qE 'Pin-Priority: *([0-9]|[1-9][0-9]|[1-4][0-9][0-9]|500)$' "$f"; then
        HINT=" (the pin's priority does not beat the main archive's 500)"
      else
        HINT=" (check the Pin: line against what apt-cache policy shows for the backports repository)"
      fi
    fi
  done
  echo "❌ apt still offers ripgrep $GOT, not the backports build$HINT"
  exit 1
fi
PLAN="$(/usr/bin/apt-get -s upgrade 2>/dev/null | grep '^Inst ' | awk '{print $2}' | sort | tr '\n' ' ')"
if [ "$PLAN" != "ripgrep " ]; then
  echo "❌ an upgrade would now touch more than ripgrep: ${PLAN}"
  exit 1
fi
V="$(/usr/bin/dpkg-query --root="$ROOT" -W -f='${Version}' ripgrep)"
if [ "$V" != "13.0.0-4build2" ]; then
  echo "❌ ripgrep was installed or changed: only write the pin, the upgrade comes later"
  exit 1
fi
echo "✅ ripgrep comes from backports, everything else stays on the main archive"
