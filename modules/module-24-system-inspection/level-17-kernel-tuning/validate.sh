#!/bin/bash
# sysctl.d/90-search.conf: exactly the settings that the live machine does not meet,
# each with a compliant value, nothing else.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f .lm-state/ready ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
f=sysctl.d/90-search.conf
[ -f "$f" ] || { echo "❌ $f does not exist yet"; exit 1; }
live() { cat "/proc/sys/$(tr . / <<< "$1")" 2>/dev/null | tr -s ' \t' ' ' | sed 's/^ //; s/ $//'; }
declare -A conf
while IFS= read -r line; do
  line=${line%$'\r'}
  case "$line" in ''|\#*|\;*|[[:space:]]*\#*|[[:space:]]*\;*) continue ;; esac
  if [[ "$line" != *=* ]]; then echo "❌ not a 'key = value' line: $line"; exit 1; fi
  key=$(sed 's/=.*//; s/^[[:space:]]*-\{0,1\}//; s/[[:space:]]*$//' <<< "$line" | tr / .)
  val=$(sed 's/^[^=]*=//; s/^[[:space:]]*//; s/[[:space:]]*$//' <<< "$line" | tr -s ' \t' ' ')
  [ -z "${conf[$key]+x}" ] || { echo "❌ $key is set twice"; exit 1; }
  conf[$key]=$val
done < "$f"
want_ge() { echo "vm.max_map_count 262144
fs.file-max 2097152
net.core.somaxconn 4096"; }
need=()
fail=0
while read -r k min; do
  cur=$(live "$k")
  [ -n "$cur" ] || { echo "❌ cannot read $k on this machine"; exit 1; }
  if [ "$cur" -ge "$min" ] 2>/dev/null; then
    [ -z "${conf[$k]+x}" ] || { echo "❌ $k is $cur here, which already meets the requirement (>= $min): leave it out"; exit 1; }
  else
    v=${conf[$k]-}
    [ -n "${conf[$k]+x}" ] || { echo "❌ $k is $cur here, below the required $min, but it is not in $f"; exit 1; }
    [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge "$min" ] || { echo "❌ $k = '$v' does not meet the requirement (>= $min)"; exit 1; }
  fi
done < <(want_ge)
cur=$(live vm.swappiness)
if [ "$cur" = 1 ]; then
  [ -z "${conf[vm.swappiness]+x}" ] || { echo "❌ vm.swappiness is already 1 here: leave it out"; exit 1; }
else
  [ -n "${conf[vm.swappiness]+x}" ] || { echo "❌ vm.swappiness is $cur here, the vendor wants 1, but it is not in $f"; exit 1; }
  [ "${conf[vm.swappiness]}" = 1 ] || { echo "❌ vm.swappiness = '${conf[vm.swappiness]}', the vendor wants exactly 1"; exit 1; }
fi
k=net.ipv4.ip_local_port_range
cur=$(live $k); lo=${cur%% *}
if [ "$lo" = 1024 ]; then
  [ -z "${conf[$k]+x}" ] || { echo "❌ $k already starts at 1024 here: leave it out"; exit 1; }
else
  [ -n "${conf[$k]+x}" ] || { echo "❌ $k is '$cur' here and must start at 1024, but it is not in $f"; exit 1; }
  read -r a b extra <<< "${conf[$k]}"
  if [ -z "$b" ] || [ -n "$extra" ] || ! [[ "$a$b" =~ ^[0-9]+$ ]]; then
    echo "❌ $k takes two numbers: the first and the last port of the range"; exit 1
  fi
  [ "$a" = 1024 ] || { echo "❌ $k must start at 1024, not $a"; exit 1; }
  [ "$b" -ge 32768 ] && [ "$b" -le 65535 ] || { echo "❌ the last port of $k should stay a sensible high port (32768-65535)"; exit 1; }
fi
for key in "${!conf[@]}"; do
  case "$key" in
    vm.max_map_count|vm.swappiness|fs.file-max|net.core.somaxconn|net.ipv4.ip_local_port_range) ;;
    *) echo "❌ $key is not one of the five vendor settings: $f must contain only those that need changing"; exit 1 ;;
  esac
done
echo "✅ $f lists exactly the ${#conf[@]} setting(s) this machine needs to change"
exit 0
