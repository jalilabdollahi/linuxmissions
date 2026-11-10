#!/bin/bash
# boot/ and lib/modules/ hold exactly the running (6.8.0-31) and newest (6.8.0-45)
# kernels; links match; untouched files unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
R=6.8.0-31-generic
N=6.8.0-45-generic
cd sysroot || exit 1

for v in 5.15.0-100-generic 5.15.0-118-generic 6.5.0-28-generic 6.8.0-9-generic; do
  left=$(ls boot/ 2>/dev/null | grep -F -- "-$v" | grep -v '^\(vmlinuz\|initrd\.img\)\(\.old\)\?$' | tr '\n' ' ')
  if [ -n "$left" ] || [ -e "lib/modules/$v" ]; then
    echo "❌ kernel $v is still installed (boot/: ${left:-none}; lib/modules/$v: $([ -e lib/modules/$v ] && echo present || echo gone))"
    exit 1
  fi
done
for v in $R $N; do
  for p in vmlinuz initrd.img config System.map; do
    f=boot/$p-$v
    if [ ! -f "$f" ]; then
      [ "$v" = "$R" ] && why="the running kernel needs it" || why="it is the newest kernel"
      echo "❌ $f is missing: $why"
      exit 1
    fi
  done
  if [ ! -d lib/modules/$v ] || [ ! -f lib/modules/$v/kernel/drivers/nvme.ko ]; then
    [ "$v" = "$R" ] && echo "❌ lib/modules/$v is damaged or gone: the running kernel loads its drivers from there" || echo "❌ lib/modules/$v is damaged or gone"
    exit 1
  fi
done
extra=$(ls lib/modules | grep -vxF -e "$R" -e "$N")
[ -z "$extra" ] || { echo "❌ unexpected entry in lib/modules: $extra"; exit 1; }
extra=$(ls boot | grep -vxF -e "vmlinuz-$R" -e "vmlinuz-$N" -e "initrd.img-$R" -e "initrd.img-$N" -e "config-$R" -e "config-$N" -e "System.map-$R" -e "System.map-$N" \
  -e vmlinuz -e vmlinuz.old -e initrd.img -e initrd.img.old -e grub -e efi -e 'memtest86+x64.bin')
[ -z "$extra" ] || { echo "❌ unexpected entry in boot/: $extra"; exit 1; }

chk() {  # chk LINK EXPECTED_BASENAME
  local t
  if [ ! -L "boot/$1" ]; then echo "❌ boot/$1 is not a symlink"; exit 1; fi
  t=$(readlink "boot/$1")
  case "$t" in "$2"|"/boot/$2") ;; *) echo "❌ boot/$1 points at '$t', expected the $3 kernel ($2)"; exit 1 ;; esac
  [ -f "boot/$2" ] || { echo "❌ boot/$1 dangles"; exit 1; }
}
chk vmlinuz "vmlinuz-$N" newest
chk initrd.img "initrd.img-$N" newest
chk vmlinuz.old "vmlinuz-$R" running
chk initrd.img.old "initrd.img-$R" running

if ! find boot/grub boot/efi boot/memtest86+x64.bin boot/*-$R boot/*-$N lib/modules/$R lib/modules/$N -type f -exec cksum {} + | sort -k3 | cmp -s - ../.lm-state/keep; then
  echo "❌ a file you meant to keep was changed or lost (boot/grub, efi, memtest or a kept kernel)"
  exit 1
fi
echo "✅ only $R (running) and $N (newest) are left, and the boot links match"
exit 0
