#!/bin/bash
# the storage class lives on the interface directories (name contains a colon)
cd capture/sys/bus/usb/devices || exit 1
for i in *:*; do
  [ "$(cat "$i/bInterfaceClass")" = 08 ] || continue
  d=${i%%:*}
  vp="$(cat "$d/idVendor"):$(cat "$d/idProduct")"
  sed 's/#.*//' $SANDBOX/usb-allowlist.txt | grep -qix "[[:space:]]*$vp[[:space:]]*" && continue
  echo "$d $vp $(cat "$d/product")"
done | sort -u > $SANDBOX/rogue_usb.txt
cat $SANDBOX/rogue_usb.txt
