#!/bin/bash
# humans.txt = accounts with UID 1000-59999 and a shell listed in etc/shells,
# plus any UID 0 account other than root. Computed from the sandbox files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/passwd etc/shells 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/passwd or etc/shells was changed; they are the audit evidence, so type 'reset' to get them back"
  exit 1
fi
if [ ! -f humans.txt ]; then
  echo "❌ humans.txt does not exist yet"
  exit 1
fi

WANT=$(awk -F: '
  NR == FNR { if ($0 !~ /^#/ && NF) ok[$0] = 1; next }
  $1 ~ /^[+-]/ || NF != 7 || $3 !~ /^[0-9]+$/ { next }
  ok[$7] && (($3 >= 1000 && $3 <= 59999) || ($3 == 0 && $1 != "root")) { print $1 }
' etc/shells etc/passwd | LC_ALL=C sort)
GOT=$(tr -d '\r' < humans.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | LC_ALL=C sort)

if [ "$GOT" = "$WANT" ]; then
  echo "✅ humans.txt lists the $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') accounts that can open a shell on web-03, toor included"
  exit 0
fi
if [ -z "$GOT" ]; then
  echo "❌ humans.txt is empty"
  exit 1
fi
if [ -n "$(printf '%s\n' "$GOT" | uniq -d)" ]; then
  echo "❌ humans.txt names an account more than once"
  exit 1
fi

while IFS= read -r name; do
  printf '%s\n' "$WANT" | grep -qxF -- "$name" && continue
  case "$name" in
    +*|-*) echo "❌ '$name' is a NIS include line, not an account (its empty UID field only looks like 0)"; exit 1 ;;
  esac
  line=$(awk -F: -v n="$name" '$1 == n { print; exit }' etc/passwd)
  if [ -z "$line" ]; then
    echo "❌ '$name' is not an account in etc/passwd; write login names, one per line"
    exit 1
  fi
  uid=$(printf '%s\n' "$line" | cut -d: -f3)
  shell=$(printf '%s\n' "$line" | cut -d: -f7)
  if [ "$name" = root ]; then
    echo "❌ leave root itself out: the ticket asks for people's accounts and for other names that have UID 0"
  elif ! grep -qxF -- "$shell" etc/shells; then
    echo "❌ $name has the shell $shell, which is not in etc/shells, so nobody can log in as $name"
  else
    echo "❌ $name has UID $uid: that is a system account, not a person (regular users are 1000-59999)"
  fi
  exit 1
done <<< "$GOT"

uid0=$(awk -F: '$1 !~ /^[+-]/ && $3 == "0" && $1 != "root" { print $1 }' etc/passwd)
if ! printf '%s\n' "$GOT" | grep -qxF -- "$uid0"; then
  echo "❌ one account is missing that is root under another name: look at the UID column for a second 0"
  exit 1
fi
missing=$(printf '%s\n' "$WANT" | grep -cvxF -f <(printf '%s\n' "$GOT"))
echo "❌ $missing person account(s) with a working login shell are missing (zsh counts too: check etc/shells)"
exit 1
