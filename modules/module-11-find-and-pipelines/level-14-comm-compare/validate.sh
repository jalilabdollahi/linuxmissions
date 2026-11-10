#!/bin/bash
# only-web1.txt / only-web2.txt = package names (no arch, no version) present
# on one host and not the other. Order is free; each name once.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs.sum ] || [ "$(cat web1.pkgs web2.pkgs 2>/dev/null | cksum)" != "$(cat .lm-state/inputs.sum)" ]; then
  echo "❌ web1.pkgs or web2.pkgs was changed or removed; type 'reset' to restore them"
  exit 1
fi

export LC_ALL=C
names() { awk -F'\t' '{ n = $1; sub(/:.*/, "", n); print n }' "$1" | sort -u; }
names web1.pkgs > .lm-state/n1
names web2.pkgs > .lm-state/n2
trap 'rm -f .lm-state/n1 .lm-state/n2' EXIT

check() {  # check FILE HOST OTHER-HOST OTHER-NAMES EXPECTED
  local f=$1 host=$2 ohost=$3 other=$4 want=$5 got dup extra missing
  if [ ! -f "$f" ]; then
    echo "❌ $f does not exist yet"
    return 1
  fi
  got=$(tr -d '\r' < "$f" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
  if [ -z "$got" ]; then
    echo "❌ $f is empty, but some packages are installed only on $host"
    return 1
  fi
  if printf '%s\n' "$got" | grep -q '[[:space:]]'; then
    echo "❌ $f has versions or other text after the names; list package names only"
    return 1
  fi
  if printf '%s\n' "$got" | grep -q ':'; then
    echo "❌ $f has names like $(printf '%s\n' "$got" | grep -m1 ':'): strip the architecture, libc6:amd64 and libc6 are the same package"
    return 1
  fi
  dup=$(printf '%s\n' "$got" | sort | uniq -d | head -1)
  if [ -n "$dup" ]; then
    echo "❌ $dup appears more than once in $f"
    return 1
  fi
  extra=$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got" | sort) | head -1)
  if [ -n "$extra" ]; then
    if grep -qx -- "$extra" "$other"; then
      echo "❌ $f lists $extra, but $ohost has it too (the versions or the architecture may differ, the package is still installed on both)"
    else
      echo "❌ $f lists $extra, which is not installed on $host"
    fi
    return 1
  fi
  missing=$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got" | sort) | grep -c .)
  if [ "$missing" -gt 0 ]; then
    echo "❌ $f is missing $missing package(s) installed only on $host (is every input sorted the way comm expects?)"
    return 1
  fi
  return 0
}

check only-web1.txt web-1 web-2 .lm-state/n2 "$(comm -23 .lm-state/n1 .lm-state/n2)" || exit 1
check only-web2.txt web-2 web-1 .lm-state/n1 "$(comm -13 .lm-state/n1 .lm-state/n2)" || exit 1
echo "✅ drift found: $(grep -c . only-web1.txt) package(s) only on web-1, $(grep -c . only-web2.txt) only on web-2"
exit 0
