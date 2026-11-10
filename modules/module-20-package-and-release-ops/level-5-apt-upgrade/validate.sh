#!/bin/bash
# kept-back.txt must equal, as a set, what the real `apt-get -s upgrade` reports
# as kept back for the sandbox system (asked fresh at validation time).
SANDBOX="$1"
export APT_CONFIG="$SANDBOX/rootfs/etc/apt/apt.conf"
EXPECT="$(/usr/bin/apt-get -s upgrade 2>/dev/null | awk '
  /^The following packages have been kept back:/ {on=1; next}
  on && /^  / {for (i=1;i<=NF;i++) print $i; next}
  {on=0}' | sort -u)"
if [ -z "$EXPECT" ]; then
  echo "❌ the sandbox changed: apt no longer keeps anything back (did you run the upgrade for real? type reset)"
  exit 1
fi
if [ ! -f "$SANDBOX/kept-back.txt" ]; then
  echo "❌ kept-back.txt does not exist yet"
  exit 1
fi
GOT="$(tr -s '[:space:]' '\n' < "$SANDBOX/kept-back.txt" | grep . | sort -u)"
if [ -z "$GOT" ]; then
  echo "❌ kept-back.txt is empty"
  exit 1
fi
N=$(echo "$EXPECT" | wc -l)
for n in $GOT; do
  if ! echo "$EXPECT" | grep -qx -- "$n"; then
    if /usr/bin/dpkg-query --root="$SANDBOX/rootfs" -W "$n" >/dev/null 2>&1; then
      echo "❌ '$n' is not kept back: a plain upgrade installs it without trouble"
    else
      echo "❌ '$n' is not an installed package (write package names only, one per line)"
    fi
    exit 1
  fi
done
MISS=$(comm -23 <(echo "$EXPECT") <(echo "$GOT") | wc -l)
if [ "$MISS" -gt 0 ]; then
  echo "❌ kept-back.txt lists $(echo "$GOT" | wc -l) of the $N packages that upgrade keeps back"
  exit 1
fi
echo "✅ kept-back.txt names exactly the $N packages that upgrade keeps back"
