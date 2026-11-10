#!/bin/bash
# modprobe-sim -n -v ixgbe must print the expected chain (with its options), and
# the only change in modprobe.d may be the offending 'install ixgbe' line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M=sysroot/etc/modprobe.d
V=6.8.0-45-generic

if ! cksum modprobe-sim bin/modprobe-sim sysroot/lib/modules/$V/modules.dep 2>/dev/null | cmp -s - .lm-state/sums; then
  echo "❌ the helper or modules.dep was changed; type 'reset' to get them back"
  exit 1
fi
if [ "$(ls -A $M | LC_ALL=C sort)" != "$(ls -A .lm-state/orig | LC_ALL=C sort)" ]; then
  echo "❌ the set of files in modprobe.d changed; edit lines, do not add, rename or delete files"
  exit 1
fi
PAT='^[[:space:]]*#?[[:space:]]*install[[:space:]]+ixgbe[[:space:]]'
for f in $(ls -A .lm-state/orig); do
  case "$f" in
    *.conf)
      if ! cmp -s <(grep -Ev "$PAT" ".lm-state/orig/$f" | grep -v '^[[:space:]]*$') <(grep -Ev "$PAT" "$M/$f" | grep -v '^[[:space:]]*$'); then
        echo "❌ $M/$f has a change beyond the offending install line"
        exit 1
      fi ;;
    *)
      if ! cmp -s ".lm-state/orig/$f" "$M/$f"; then
        echo "❌ $M/$f was changed: modprobe ignores it anyway, so it was never the problem"
        exit 1
      fi ;;
  esac
done
OUT=$(./modprobe-sim -n -v ixgbe 2>&1)
WANT='insmod /lib/modules/6.8.0-45-generic/kernel/drivers/dca/dca.ko
insmod /lib/modules/6.8.0-45-generic/kernel/drivers/pps/pps_core.ko
insmod /lib/modules/6.8.0-45-generic/kernel/drivers/ptp/ptp.ko
insmod /lib/modules/6.8.0-45-generic/kernel/drivers/net/mdio.ko
insmod /lib/modules/6.8.0-45-generic/kernel/drivers/net/ethernet/intel/ixgbe/ixgbe.ko allow_unsupported_sfp=1'
if [ "$OUT" = "$WANT" ]; then
  echo "✅ modprobe-sim now prints the full insmod chain for ixgbe and modprobe.d changed only by the offending line"
  exit 0
fi
if printf '%s\n' "$OUT" | grep -q '^install '; then
  echo "❌ ixgbe still has an 'install' rule: modprobe runs that command instead of loading the module (see: ./modprobe-sim -c)"
elif printf '%s\n' "$OUT" | grep -q 'ixgbe.ko$'; then
  echo "❌ ixgbe now loads, but without its option: a line you did not need to touch was changed"
else
  echo "❌ ./modprobe-sim -n -v ixgbe does not print the insmod chain yet: $(printf '%s\n' "$OUT" | head -1)"
fi
exit 1
