#!/bin/bash
# facts.env must hold the live uname -s, -r and -m, one KEY=value each.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f facts.env ] || { echo "❌ facts.env is missing; type 'reset' to get it back"; exit 1; }

get() {   # value of KEY (last assignment), surrounding quotes removed
  grep -E "^[[:space:]]*$1[[:space:]]*=" facts.env | tail -1 | sed -E 's/^[^=]*=//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/'
}
for k in KERNEL_NAME KERNEL_RELEASE ARCH; do
  n=$(grep -cE "^[[:space:]]*$k[[:space:]]*=" facts.env)
  [ "$n" -eq 1 ] || { echo "❌ facts.env must set $k exactly once (found $n)"; exit 1; }
  [ -n "$(get $k)" ] || { echo "❌ $k is still empty"; exit 1; }
done

name=$(get KERNEL_NAME); rel=$(get KERNEL_RELEASE); arch=$(get ARCH)
if [ "$name" != "$(uname -s)" ]; then
  echo "❌ KERNEL_NAME=$name is not what this machine reports as its kernel name"; exit 1
fi
if [ "$rel" != "$(uname -r)" ]; then
  case $rel in
    *" "*) echo "❌ KERNEL_RELEASE has spaces in it: that is more than the release (the version string is a different field)";;
    *)     echo "❌ KERNEL_RELEASE=$rel is not the kernel release this machine reports";;
  esac
  exit 1
fi
if [ "$arch" != "$(uname -m)" ]; then
  if [ "$arch" = unknown ]; then
    echo "❌ ARCH=unknown: that is what the processor field often says; you want the machine hardware name"
  else
    echo "❌ ARCH=$arch is not the machine hardware name this machine reports"
  fi
  exit 1
fi
echo "✅ facts.env matches this machine: $name $rel $arch"
exit 0
