#!/bin/bash
# rogue_usb.txt must list exactly the mass-storage devices of the capture that
# are not allowlisted, one `port vid:pid product` line per device.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -d capture/sys ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f rogue_usb.txt ] || { echo "❌ rogue_usb.txt does not exist yet"; exit 1; }
got=$(tr -d '\r' < rogue_usb.txt | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | grep -v '^$' | LC_ALL=C sort)
want=$(cat .lm-state/expected)
[ -n "$got" ] || { echo "❌ rogue_usb.txt is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ $(echo "$want" | wc -l | tr -d ' ') unlisted USB storage device(s) found"; exit 0
fi
if [ "$(printf '%s\n' "$got" | sort -u | wc -l)" -ne "$(printf '%s\n' "$got" | wc -l)" ]; then
  echo "❌ a device is listed more than once (one line per device, even if it has several interfaces)"; exit 1
fi
bad=$(printf '%s\n' "$got" | grep -Ev '^[0-9]+-[0-9.]+ [0-9a-f]{4}:[0-9a-f]{4} .+$' | head -1)
if [ -n "$bad" ]; then
  echo "❌ '$bad' does not look like: port vid:pid product (lowercase hex ids, as in sysfs)"; exit 1
fi
extra=$(comm -13 <(echo "$want") <(echo "$got") | head -1)
miss=$(comm -23 <(echo "$want") <(echo "$got") | wc -l | tr -d ' ')
if [ -n "$extra" ]; then
  port=${extra%% *}
  vp=$(echo "$extra" | cut -d' ' -f2)
  if grep -qix "$vp" <(sed 's/[[:space:]]*#.*//' usb-allowlist.txt); then
    echo "❌ '$port' ($vp) is on the allowlist, it must not be listed"
  elif [ ! -f capture/sys/bus/usb/devices/$port/idVendor ]; then
    echo "❌ '$port' is not a USB device port in the capture (interfaces and hubs have their own names)"
  elif ! grep -qx '08' capture/sys/bus/usb/devices/$port:*/bInterfaceClass 2>/dev/null; then
    echo "❌ '$port' has no mass-storage interface (class 08), it is not a storage device"
  else
    echo "❌ the line for '$port' is wrong (check the vid:pid and the product name against sysfs)"
  fi
elif [ "$miss" -gt 0 ]; then
  echo "❌ $miss rogue storage device(s) still missing from rogue_usb.txt"
fi
exit 1
