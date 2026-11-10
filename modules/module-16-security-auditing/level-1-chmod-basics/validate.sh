#!/bin/bash
# home/.ssh: dir 700, private keys (found by their PEM header, not their name)
# 600, *.pub 644, authorized_keys 600, config 600, known_hosts 600 or 644.
# Contents and everything else under home/ must be unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
S=home/.ssh

[ -d "$S" ] || { echo "❌ home/.ssh is missing"; exit 1; }
if ! ( cd home/.ssh && LC_ALL=C find . -type f | LC_ALL=C sort | xargs cksum ) | cmp -s - .lm-state/ssh-sums; then
  echo "❌ a file in home/.ssh was changed, added or removed; only permissions should change (type 'reset' to start over)"
  exit 1
fi
if ! ( cd home && LC_ALL=C find . -path ./.ssh -prune -o -type f -print | LC_ALL=C sort | xargs cksum ) | cmp -s - .lm-state/rest-sums; then
  echo "❌ file contents elsewhere under home/ were changed"; exit 1
fi
rest=$( cd home && LC_ALL=C find . -path ./.ssh -prune -o -print | LC_ALL=C sort | while IFS= read -r f; do echo "$(mode "$f") $f"; done )
if [ "$rest" != "$(cat .lm-state/rest-modes)" ]; then
  bad=$(diff <(echo "$rest") .lm-state/rest-modes | grep '^>' | head -1 | cut -d' ' -f3)
  echo "❌ the mode of home/${bad#./} was changed, but only home/.ssh was supposed to be fixed"; exit 1
fi

m=$(mode "$S")
if [ "$m" != 700 ]; then
  echo "❌ the folder home/.ssh has mode $m: it must be reachable by its owner only"; exit 1
fi
for f in "$S"/* "$S"/.[!.]*; do
  [ -f "$f" ] || continue
  name=${f##*/}; m=$(mode "$f")
  if grep -q 'PRIVATE KEY-----' "$f"; then
    [ "$m" = 600 ] || { echo "❌ $name is a private key but has mode $m: group or others can still reach it, or the owner cannot use it"; exit 1; }
    continue
  fi
  case "$name" in
    *.pub)         want=644 ;;
    authorized_keys|config) want=600 ;;
    known_hosts)   [ "$m" = 600 ] || [ "$m" = 644 ] && continue; want="600 or 644" ;;
    *)             continue ;;
  esac
  [ "$m" = "$want" ] || { echo "❌ $name has mode $m, which is not what OpenSSH expects for this kind of file"; exit 1; }
done
echo "✅ home/.ssh is locked down: both private keys are 600, the folder is 700, the rest is in order"
exit 0
