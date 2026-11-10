#!/bin/bash
# reboot_needed.txt must list the hosts whose running release (uname field 3) is
# older (sort -V) than the newest "ii linux-image-<digit>" in kernels.txt. The
# expectation is computed from the fleet files, which must be unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cksum fleet/*/* 2>/dev/null | cmp -s - .lm-state/sums; then
  echo "❌ something under fleet/ was changed; it is the evidence, so type 'reset' to get it back"
  exit 1
fi
[ -f reboot_needed.txt ] || { echo "❌ reboot_needed.txt does not exist yet"; exit 1; }
WANT=""
for d in fleet/*/; do
  h=$(basename "$d")
  run=$(awk '{print $3}' "$d/uname.txt")
  newest=$(awk '$1 == "ii" && $2 ~ /^linux-image-[0-9]/ { sub("linux-image-", "", $2); print $2 }' "$d/kernels.txt" | sort -V | tail -n 1)
  if [ "$run" != "$newest" ] && [ "$(printf '%s\n%s\n' "$run" "$newest" | sort -V | head -n 1)" = "$run" ]; then
    WANT="$WANT$h
"
  fi
done
WANT=$(printf '%s' "$WANT" | LC_ALL=C sort)
GOT=$(tr -d '\r' < reboot_needed.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')

if [ "$GOT" = "$WANT" ]; then
  echo "✅ reboot_needed.txt names the $(echo "$WANT" | wc -l | tr -d ' ') hosts that run an older kernel than they have installed"
  exit 0
fi
if [ "$GOT" = "$(printf '%s\n' "$GOT" | LC_ALL=C sort)" ] || [ -z "$GOT" ]; then :; else
  if [ "$(printf '%s\n' "$GOT" | LC_ALL=C sort)" = "$WANT" ]; then
    echo "❌ the right hosts, but not sorted"
    exit 1
  fi
fi
while IFS= read -r h; do
  [ -n "$h" ] || continue
  if [ ! -d "fleet/$h" ]; then echo "❌ '$h' is not a host under fleet/"; exit 1; fi
  if ! printf '%s\n' "$WANT" | grep -qxF -- "$h"; then
    run=$(awk '{print $3}' "fleet/$h/uname.txt")
    newest=$(awk '$1 == "ii" && $2 ~ /^linux-image-[0-9]/ { sub("linux-image-", "", $2); print $2 }' "fleet/$h/kernels.txt" | sort -V | tail -n 1)
    echo "❌ $h does not need a reboot: it runs $run and the newest installed kernel image is $newest"
    exit 1
  fi
done <<< "$GOT"
miss=$(printf '%s\n' "$WANT" | grep -vxF -f <(printf '%s\n' "$GOT") | head -1)
echo "❌ the list is incomplete; for example $miss runs a kernel older than one it has installed"
exit 1
