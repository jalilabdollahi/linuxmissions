#!/bin/bash
# why.env must hold the real candidate (asked from apt-cache), its Origin and
# the preferences file whose pin is the winning one. Preferences must be unchanged.
SANDBOX="$1"
export APT_CONFIG="$SANDBOX/rootfs/etc/apt/apt.conf"
F="$SANDBOX/why.env"
if [ ! -f "$F" ]; then
  echo "❌ why.env does not exist yet"
  exit 1
fi
get() { grep -E "^$1=" "$F" | tail -1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' -e 's/[[:space:]]*$//'; }
CAND="$(get CANDIDATE)"; ORIG="$(get ORIGIN)"; PREF="$(get PREF_FILE)"
for k in CANDIDATE ORIGIN PREF_FILE; do
  if ! grep -qE "^$k=." "$F"; then
    echo "❌ why.env has no $k= line (or it is empty)"
    exit 1
  fi
done
{ read -r E_CAND; read -r E_ORIG; read -r E_PREF; } < "$SANDBOX/.lm/expect"
REAL="$(/usr/bin/apt-cache policy nginx 2>/dev/null | awk '/Candidate:/ {print $2}')"
if [ "$REAL" != "$E_CAND" ]; then
  echo "❌ the preferences were changed (apt now picks nginx $REAL): put them back with reset and only investigate"
  exit 1
fi
if [ "$CAND" != "$E_CAND" ]; then
  echo "❌ CANDIDATE=$CAND is not the version apt would install for nginx"
  exit 1
fi
if [ "$ORIG" != "$E_ORIG" ]; then
  echo "❌ ORIGIN=$ORIG is not where that version comes from (look at the o= part of its policy line)"
  exit 1
fi
case "$PREF" in /*) P="$PREF" ;; *) P="$SANDBOX/${PREF#./}" ;; esac
if [ ! -f "$P" ]; then
  echo "❌ PREF_FILE=$PREF does not exist"
  exit 1
fi
if [ "$(readlink -f "$P")" != "$(readlink -f "$SANDBOX/$E_PREF")" ]; then
  if grep -q 'Package: nginx' "$P" 2>/dev/null; then
    echo "❌ $PREF pins nginx too, but it is not the pin that decides: compare the priorities"
  else
    echo "❌ $PREF is not the preferences file that makes this version win"
  fi
  exit 1
fi
echo "✅ nginx $CAND from $ORIG wins because of $(basename "$P")"
