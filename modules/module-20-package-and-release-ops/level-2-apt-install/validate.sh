#!/bin/bash
# fluxd must be installed at the ticket's version, libflux1 at the version that
# release accepts, and every other package must be as it was.
SANDBOX="$1"
read -r TARGET NEED < "$SANDBOX/.lm/target"
Q=(/usr/bin/dpkg-query --root="$SANDBOX/rootfs")
state() { "${Q[@]}" -W -f='${db:Status-Abbrev} ${Version}\n' "$1" 2>/dev/null; }

FX="$(state fluxd)"
if [ -z "$FX" ] || [ "$(echo $FX | cut -d' ' -f1)" != "ii" ]; then
  echo "❌ fluxd is not installed yet"
  exit 1
fi
FXV="$(echo $FX | cut -d' ' -f2)"
if [ "$FXV" != "$TARGET" ]; then
  echo "❌ fluxd $FXV is installed; the ticket asks for ${TARGET%-*}"
  exit 1
fi
LB="$(state libflux1)"
LBV="$(echo $LB | cut -d' ' -f2)"
if [ "$(echo $LB | cut -d' ' -f1)" != "ii" ] || [ "$LBV" != "$NEED" ]; then
  echo "❌ libflux1 is $LBV, but fluxd $FXV needs a different one (see its Depends)"
  exit 1
fi
if ! APT_CONFIG="$SANDBOX/rootfs/etc/apt/apt.conf" /usr/bin/apt-get check >/dev/null 2>&1; then
  echo "❌ the package system has broken dependencies (apt-get check fails)"
  exit 1
fi
NOW="$("${Q[@]}" -W -f='${Package} ${Version}\n' | grep -v '^base-files ' | grep -v -e '^fluxd ' -e '^libflux1 ' | sort)"
WAS="$(grep -v -e '^fluxd ' -e '^libflux1 ' "$SANDBOX/.lm/baseline")"
if [ "$NOW" != "$WAS" ]; then
  CH="$(diff <(echo "$WAS") <(echo "$NOW") | grep '^[<>]' | head -1)"
  echo "❌ another package changed too ($CH): only fluxd and its library should move"
  exit 1
fi
echo "✅ fluxd $FXV runs with libflux1 $LBV and nothing else changed"
