#!/bin/bash
# status.txt = one line "user P|L|NP" per shadow entry (the `passwd -S -a` rule:
# empty password field = NP; field starting with ! or * = L; else P).
# np.txt = the accounts with no password, one per line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/shadow etc/passwd 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/shadow or etc/passwd was changed; they are the evidence, so type 'reset' to get them back"
  exit 1
fi
for f in status.txt np.txt; do
  [ -f "$f" ] || { echo "❌ $f does not exist yet"; exit 1; }
done

WANT=$(awk -F: '{ s = ($2 == "") ? "NP" : (($2 ~ /^[!*]/) ? "L" : "P"); print $1, s }' etc/shadow | LC_ALL=C sort)
GOT=$(tr -d '\r' < status.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]][[:space:]]*/ /g' | grep -v '^$' | LC_ALL=C sort)
if [ -z "$GOT" ]; then
  echo "❌ status.txt is empty"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -Evq '^[^ ]+ (P|L|NP)$'; then
  echo "❌ every line of status.txt must be exactly 'user P', 'user L' or 'user NP'; not this one: $(printf '%s\n' "$GOT" | grep -Ev '^[^ ]+ (P|L|NP)$' | head -n 1)"
  exit 1
fi
if [ "$GOT" != "$WANT" ]; then
  while read -r u s; do
    g=$(printf '%s\n' "$GOT" | awk -v u="$u" '$1 == u { print $2 }')
    if [ -z "$g" ]; then
      echo "❌ status.txt has no line for $u (every account in etc/shadow needs one)"
      exit 1
    fi
    if [ "$g" != "$s" ]; then
      if [ "$s" = L ]; then
        echo "❌ $u is reported as $g, but its password field starts with ! or *: that account is locked"
      elif [ "$s" = NP ]; then
        echo "❌ $u is reported as $g, but its password field is empty: there is no password at all"
      else
        echo "❌ $u is reported as $g, but its password field holds a usable hash"
      fi
      exit 1
    fi
  done <<< "$WANT"
  echo "❌ status.txt has a line for something that is not an account in etc/shadow, or lists one twice"
  exit 1
fi

WNP=$(printf '%s\n' "$WANT" | awk '$2 == "NP" { print $1 }')
GNP=$(tr -d '\r' < np.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | LC_ALL=C sort)
if [ "$GNP" != "$WNP" ]; then
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    printf '%s\n' "$WNP" | grep -qxF -- "$u" && continue
    echo "❌ np.txt: $u does have a password field (even a locked one): np.txt is only for accounts with no password at all"
    exit 1
  done <<< "$GNP"
  echo "❌ np.txt is missing an account with no password at all (service accounts count too)"
  exit 1
fi
echo "✅ status.txt covers every account and np.txt names the $(printf '%s\n' "$WNP" | wc -l | tr -d ' ') with no password"
exit 0
