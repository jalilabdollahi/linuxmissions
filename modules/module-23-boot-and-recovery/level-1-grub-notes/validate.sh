#!/bin/bash
# default_entry.txt / default_kernel.txt must match the entry set default="1>2"
# selects. Expected values were fixed at setup; grub.cfg must be unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cksum sysroot/boot/grub/grub.cfg 2>/dev/null | cmp -s - .lm-state/cfg; then
  echo "❌ grub.cfg was changed; it is the evidence, so type 'reset' to get it back"
  exit 1
fi
for f in default_entry.txt default_kernel.txt; do
  [ -s "$f" ] || { echo "❌ $f does not exist yet (or is empty)"; exit 1; }
done
clean() { tr -d '\r' < "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$'; }
TITLE=$(clean default_entry.txt)
KERNEL=$(clean default_kernel.txt)
WT=$(cat .lm-state/title); WK=$(cat .lm-state/kernel)

if [ "$TITLE" != "$WT" ]; then
  case "$TITLE" in
    Ubuntu) echo "❌ default_entry.txt names the first entry in the file, but grub.cfg sets a different default" ;;
    "Advanced options for Ubuntu"|"UEFI Firmware Settings") echo "❌ default_entry.txt names a top-level item; set default points at an entry, not at the submenu or the firmware item" ;;
    *recovery*) echo "❌ default_entry.txt names a recovery entry; check how the entries are counted (from 0)" ;;
    *"'"*) echo "❌ default_entry.txt contains quote characters; write the title without the quotes" ;;
    *) if grep -qF "menuentry '$TITLE'" sysroot/boot/grub/grub.cfg; then
         echo "❌ '$TITLE' is a real entry, but not the one set default selects: count again from 0, with the submenu"
       else
         echo "❌ default_entry.txt has no entry title from grub.cfg; copy the text between the quotes exactly"
       fi ;;
  esac
  exit 1
fi
if [ "$KERNEL" != "$WK" ]; then
  echo "❌ default_kernel.txt is not the version that the default entry loads (look at its linux line)"
  exit 1
fi
echo "✅ GRUB boots '$WT', which loads kernel $WK"
exit 0
