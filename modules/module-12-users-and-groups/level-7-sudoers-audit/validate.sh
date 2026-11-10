#!/bin/bash
# root-capable.txt = users with an unrestricted ALL=(ALL[:ALL]) ... ALL rule on
# db-01, through a username, the ADMINS alias, or %group (members of etc/group),
# in etc/sudoers or in the drop-ins sudo actually reads (not README~, .bak, .conf).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/sudoers etc/group etc/sudoers.d/* 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/sudoers, etc/sudoers.d or etc/group was changed; they are the evidence, so type 'reset' to get them back"
  exit 1
fi
if [ ! -f root-capable.txt ]; then
  echo "❌ root-capable.txt does not exist yet"
  exit 1
fi

WANT="alice
ci-runner
dmitri
kai
lena
noor
omar
vendor"
GOT=$(tr -d '\r' < root-capable.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | LC_ALL=C sort -u)
[ "$GOT" = "$WANT" ] && {
  echo "✅ root-capable.txt lists the 8 people and accounts that can become full root on db-01"
  exit 0
}
if [ -z "$GOT" ]; then
  echo "❌ root-capable.txt is empty"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -qx root; then
  echo "❌ root itself is not on the list: write the other accounts that can become root"
  exit 1
fi
while IFS= read -r u; do
  printf '%s\n' "$WANT" | grep -qxF -- "$u" && continue
  case $u in
    mallory) echo "❌ mallory's rule is in sudoers.d/README~: sudo skips file names that end in ~" ;;
    legacy)  echo "❌ legacy's rule is in sudoers.d/70-legacy.conf: sudo skips file names that contain a dot" ;;
    zoe)     echo "❌ zoe's full-root rule names another host; it does not apply on db-01" ;;
    pavel|rosa) echo "❌ $u: a rule that is limited to certain commands, or to another runas user, is not full root" ;;
    wei)     echo "❌ wei: %deploy may only restart the app, which is not full root" ;;
    tomas)   echo "❌ tomas: his only unrestricted rule is commented out, and %deploy/%adm are limited to a few commands" ;;
    *)       echo "❌ '$u' cannot become full root on db-01 (check that every rule you rely on is really read by sudo, covers ALL commands and is for this host)" ;;
  esac
  exit 1
done <<< "$GOT"
while IFS= read -r u; do
  printf '%s\n' "$GOT" | grep -qxF -- "$u" && continue
  case $u in
    kai|noor)   echo "❌ a member of a group that gets full root through sudoers.d is missing: group members come from etc/group" ;;
    ci-runner|vendor) echo "❌ an account with a full-root rule in sudoers.d is missing: the main file includes that directory with #includedir, which is a directive, not a comment" ;;
    lena|omar|dmitri) echo "❌ a member of the User_Alias ADMINS is missing (read the alias to its last line)" ;;
    *)          echo "❌ a member of a group with a full-root rule in sudoers is missing: group members come from etc/group" ;;
  esac
  exit 1
done <<< "$WANT"
echo "❌ root-capable.txt does not match"
exit 1
