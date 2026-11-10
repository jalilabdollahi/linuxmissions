#!/bin/bash
# unbound.txt: network (01xx/02xx) devices without a "Kernel driver in use",
# as "slot [vendor:device] module" in file order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -s capture/lspci.txt ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f unbound.txt ] || { echo "❌ unbound.txt does not exist yet"; exit 1; }
want=$(cat .lm-state/expected)
got=$(tr -d '\r' < unbound.txt | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | grep -v '^$')
[ -n "$got" ] || { echo "❌ unbound.txt is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ $(wc -l <<< "$want" | tr -d ' ') unbound network/storage devices found"; exit 0
fi
if awk 'NF != 3 || $2 !~ /^\[[0-9a-f]{4}:[0-9a-f]{4}\]$/ { bad = 1 } END { exit !bad }' <<< "$got"; then
  echo "❌ every line must look like: 00:1f.0 [8086:1234] module (the vendor:device ID in square brackets, not the class code)"; exit 1
fi
extra=$(comm -13 <(sort <<< "$want") <(sort -u <<< "$got") | head -1)
miss=$(comm -23 <(sort <<< "$want") <(sort -u <<< "$got") | wc -l | tr -d ' ')
if [ -n "$extra" ]; then
  slot=${extra%% *}
  if grep -q "^$slot " <<< "$want"; then
    echo "❌ '$extra': the ID or the module of that device is wrong (module = first name on its Kernel modules line, - if none)"
  else
    cls=$(grep "^$slot " capture/lspci.txt | head -1 | sed 's/^[^ ]* //; s/ \[.*//')
    echo "❌ $slot ($cls) is either bound to a driver or not a network/storage controller"
  fi
elif [ "$miss" -gt 0 ]; then
  echo "❌ $miss unbound network/storage device(s) missing (a device with a Kernel modules line but no Kernel driver in use is unbound)"
else
  echo "❌ the lines are right but not in the order of the file (or one is repeated)"
fi
exit 1
