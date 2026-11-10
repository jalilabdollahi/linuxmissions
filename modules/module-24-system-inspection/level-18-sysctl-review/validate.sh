#!/bin/bash
# effective.txt must hold, for every key set by the files systemd-sysctl really applies,
# `key=value file`, sorted by key. Keys of masked files must not appear.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -d capture/etc ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f effective.txt ] || { echo "❌ effective.txt does not exist yet"; exit 1; }
got=$(tr -d '\r' < effective.txt | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//; s/ *= */=/' | grep -v '^$')
want=$(cat .lm-state/expected)
[ -n "$got" ] || { echo "❌ effective.txt is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ all $(wc -l <<< "$want" | tr -d ' ') effective settings and their files are right"; exit 0
fi
if grep -qE '^[^ =]*/[^ =]*=' <<< "$got"; then
  echo "❌ write keys with dots (net.ipv4.ip_forward): the slash form is the same key"; exit 1
fi
bad=$(grep -vE '^[a-z0-9_.-]+=.* [a-z]+/[^ ]+$' <<< "$got" | head -1)
if [ -n "$bad" ]; then echo "❌ '$bad' does not look like: key=value path"; exit 1; fi
if [ "$(cut -d= -f1 <<< "$got" | sort -u | wc -l)" -ne "$(wc -l <<< "$got")" ]; then
  echo "❌ a key is listed twice: only the effective (last) assignment counts"; exit 1
fi
if grep -q ' etc/sysctl\.conf$' <<< "$got"; then
  echo "❌ etc/sysctl.conf is applied through its symlink etc/sysctl.d/99-sysctl.conf: that is the name that sorts"; exit 1
fi
keys=$(cut -d= -f1 <<< "$got")
for k in $(cat .lm-state/only_masked); do
  if grep -qx "$k" <<< "$keys"; then
    echo "❌ $k is only set by a file that a same-named file in a higher-priority directory hides: it is not applied at all"; exit 1
  fi
done
if [ "$(sort <<< "$keys")" != "$keys" ]; then echo "❌ sort the lines by key"; exit 1; fi
wk=$(cut -d= -f1 <<< "$want")
miss=$(comm -13 <(sort <<< "$keys") <(sort <<< "$wk") | head -1)
if [ -n "$miss" ]; then echo "❌ the setting '$miss' is missing"; exit 1; fi
extra=$(comm -23 <(sort <<< "$keys") <(sort <<< "$wk") | head -1)
if [ -n "$extra" ]; then echo "❌ '$extra' is not set by any applied file"; exit 1; fi
k=$(diff <(echo "$want") <(echo "$got") | grep '^>' | head -1 | sed 's/^> //; s/=.*//')
gl=$(grep "^$k=" <<< "$got"); wl=$(grep "^$k=" <<< "$want")
if [ "${gl%% *}" != "${wl%% *}" ]; then
  echo "❌ the value of $k is wrong: files are applied in name order across all directories, the last one wins"
else
  echo "❌ the value of $k is right, but another file sets it last"
fi
exit 1
