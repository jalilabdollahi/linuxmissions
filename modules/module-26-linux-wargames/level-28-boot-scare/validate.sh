#!/bin/bash
SB="$1"; cd "$SB" || exit 1
L="$(cd "$(dirname "$0")" && pwd)"
now=$( cd sysroot && find boot/vmlinuz* boot/initrd.img* dev/disk opt -type f -o -type l | sort | while read -r f; do echo "$f $(readlink "$f" 2>/dev/null || sha256sum < "$f" | cut -c1-64)"; done )
if [ "$now" != "$(cat .lm/frozen.txt)" ]; then echo "❌ kernels, initrds, the /dev/disk tree or /opt were changed: those are the hardware, fix the configuration instead"; exit 1; fi
if [ "$(grep -c "menuentry '" sysroot/boot/grub/grub.cfg)" -lt 5 ]; then echo "❌ boot entries were removed from grub.cfg: pick the right entry instead"; exit 1; fi
out=$(python3 "$L/boot-sim" --systemctl "$L/../../../mocks/systemd/systemctl" sysroot 2>&1); rc=$?
if [ $rc -ne 0 ] || [ "$(tail -1 <<<"$out")" != "Reached multi-user.target" ]; then
  echo "❌ boot-sim still stops: $(grep -m1 -E '^(error|ALERT|Gave up|\[ TIME|\[FAILED|Failed|kernel: panic|boot-sim)' <<<"$out" | cut -c1-110)"; exit 1; fi
read -r NEWR NEWB NEWS OLDR OLDB OLDS OLDD < .lm/uuids
if grep -q "UUID=$OLDD" sysroot/etc/fstab && ! grep "$OLDD" sysroot/etc/fstab | grep -q nofail; then echo "❌ fstab still depends on the missing data disk"; exit 1; fi
echo "✅ boot-sim reaches multi-user.target with the hardware untouched"
