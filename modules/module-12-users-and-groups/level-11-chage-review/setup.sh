#!/bin/bash
# Password expiry review on app-04, ticket date 2026-11-10 (the mock's "today").
# etc/shadow has twelve people plus system accounts; which person gets which
# situation is random. Cases: expires in a few days, exactly in 14 days (counts),
# in 15 days (does not), long expired, 99999 (never), last change 0 (must change at
# next login = expired now), empty max field, empty last-change field, far away,
# a locked account that still expires soon, and an ACCOUNT expiry (field 8) soon
# while the password is fine.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc bin .lm .lm-state
M="$(cd "$(dirname "$0")/../../../mocks/accounts" && pwd)"
cp "$M/chage" bin/
echo 2026-11-10 > .lm/now
today=$(( $(date -u -d 2026-11-10 +%s) / 86400 ))

# shuffle the cases over the people
people=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); n = split("amara bjorn chiara dev elif farouk greta hugo ines jonah kofi liv", a, " ")
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t }
  for (i = 1; i <= n; i++) print a[i] }')
cases="soon exact14 exact15 expired never mustchange nomax nolast far locked soon2 acctexp"

hash='$y$j9T$k3Qw1mZp0aXc7uYb5Nl2e.$Hq0zWk8e1VtLr4oJdUo9sXn6cYfA3bGmEiPzR7vTwK2'
{
  echo 'root:*:19800:0:99999:7:::'
  echo 'daemon:*:19800:0:99999:7:::'
  echo 'www-data:*:19800:0:99999:7:::'
  echo 'sshd:*:19800:0:99999:7:::'
} > etc/shadow
{
  echo 'root:x:0:0:root:/root:/bin/bash'
  echo 'daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin'
  echo 'www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin'
  echo 'sshd:x:105:65534::/run/sshd:/usr/sbin/nologin'
} > etc/passwd

uid=1000
for c in $cases; do
  u=$(printf '%s\n' "$people" | sed -n "$(( uid - 999 ))p")
  pw="$hash"; lastchg=; min=0; max=90; warn=7; inact=; exp=
  case $c in
    soon)       off=$((1 + RANDOM % 6));  lastchg=$((today + off - 90)) ;;
    soon2)      off=$((7 + RANDOM % 5));  max=180; lastchg=$((today + off - 180)) ;;
    exact14)    max=60;  lastchg=$((today + 14 - 60)) ;;
    exact15)    max=60;  lastchg=$((today + 15 - 60)) ;;
    expired)    off=$((5 + RANDOM % 40)); lastchg=$((today - off - 90)) ;;
    never)      max=99999; lastchg=$((today - 400 - RANDOM % 200)) ;;
    mustchange) lastchg=0 ;;
    nomax)      max=; lastchg=$((today - 5)) ;;
    nolast)     lastchg=; max=90 ;;
    far)        max=365; lastchg=$((today - 30 - RANDOM % 60)) ;;
    locked)     pw="!$hash"; off=$((2 + RANDOM % 8)); max=30; lastchg=$((today + off - 30)) ;;
    acctexp)    max=99999; lastchg=$((today - 100)); exp=$((today + 4 + RANDOM % 5)) ;;
  esac
  echo "$u:$pw:$lastchg:$min:$max:$warn:$inact:$exp:" >> etc/shadow
  echo "$u:x:$uid:$uid:${u^}:/home/$u:/bin/bash" >> etc/passwd
  uid=$((uid + 1))
done

cksum etc/shadow etc/passwd .lm/now > .lm-state/inputs
