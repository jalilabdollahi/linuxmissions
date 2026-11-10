#!/bin/bash
# limits.txt = the live soft / hard nofile limits and fd count of the indexer;
# the effective LimitNOFILE of indexer.service in sysroot/ is 65536.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/indexer.pid ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
pid=$(cat .lm-state/indexer.pid)
if ! tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q 'indexer\.py'; then
  echo "❌ the indexer process is gone (it is the evidence): type 'reset' to start over"; exit 1
fi
[ -f limits.txt ] || { echo "❌ limits.txt does not exist yet"; exit 1; }
soft=$(awk '/^Max open files/ {print $4}' "/proc/$pid/limits")
hard=$(awk '/^Max open files/ {print $5}' "/proc/$pid/limits")
open=$(ls "/proc/$pid/fd" | wc -l | tr -d ' ')
got=$(tr -d '\r' < limits.txt | sed 's/[[:space:]]//g' | grep -v '^$')
want=$(printf 'soft=%s\nhard=%s\nopen=%s' "$soft" "$hard" "$open")
if [ "$got" != "$want" ]; then
  if [ "$(wc -l <<< "$got")" -ne 3 ] || ! grep -q '^soft=' <<< "$got" || ! grep -q '^hard=' <<< "$got" || ! grep -q '^open=' <<< "$got"; then
    echo "❌ limits.txt must have the three lines soft=, hard= and open= (in that order)"
  elif [ "$(grep '^open=' <<< "$got")" != "open=$open" ]; then
    echo "❌ the open= count does not match the indexer's open file descriptors right now"
  else
    echo "❌ soft= or hard= does not match the limit of the running indexer (read it from the process, not from a config file)"
  fi
  exit 1
fi
d=sysroot/etc/systemd/system/indexer.service.d
eff=""; src=""
for f in $(ls $d/*.conf 2>/dev/null | LC_ALL=C sort); do
  v=$(awk '
    /^[[:space:]]*\[/ { sec = $0; gsub(/[[:space:]]/, "", sec); next }
    sec == "[Service]" && /^[[:space:]]*LimitNOFILE[[:space:]]*=/ { sub(/^[^=]*=[[:space:]]*/, ""); gsub(/[[:space:]]+$/, ""); v = $0 }
    END { print v }' "$f")
  [ -n "$v" ] && { eff=$v; src=$f; }
done
if [ -z "$eff" ]; then
  if grep -v '^[[:space:]]*#' sysroot/etc/security/limits.conf sysroot/etc/security/limits.d/* 2>/dev/null | grep -q nofile; then
    echo "❌ limits.conf is applied by PAM at login: a systemd service never goes through PAM, so that edit does nothing for it. Use a unit drop-in"
  else
    echo "❌ no drop-in in $d sets LimitNOFILE= under [Service]"
  fi
  exit 1
fi
case "$eff" in 65536|65536:65536) ;; *)
  if [ "$(basename "$src")" = 10-legacy.conf ] && grep -v '^[[:space:]]*#' sysroot/etc/security/limits.conf sysroot/etc/security/limits.d/* 2>/dev/null | grep -q nofile; then
    echo "❌ limits.conf is applied by PAM at login: a systemd service never goes through PAM, so that edit does nothing for it. Use a unit drop-in"
  elif [ "$(basename "$src")" = 10-legacy.conf ]; then
    echo "❌ the effective LimitNOFILE is still $eff, set by 10-legacy.conf: nothing outranks it yet (drop-ins apply in name order, the last wins)"
  else
    echo "❌ the effective LimitNOFILE of indexer.service is $eff (last set by $(basename "$src")): drop-ins are applied in name order and the last one wins"
  fi
  exit 1 ;;
esac
echo "✅ limits recorded (soft $soft, hard $hard, $open open) and LimitNOFILE=65536 takes effect for the service"
exit 0
