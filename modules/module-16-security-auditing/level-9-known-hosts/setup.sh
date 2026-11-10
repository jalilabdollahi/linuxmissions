#!/bin/bash
# Host Key Changed. known_hosts with hashed names (ssh-keygen -H): six other
# hosts, the old ed25519 and ecdsa keys of git.internal, and the same old keys
# under [10.4.0.7]:2222. keyscan.txt is ssh-keyscan output (with comment lines)
# holding two NEW keys for git.internal. Throwaway keys are generated for every
# run; the entry order is shuffled. The state files record which hashed lines
# must stay and which are the old ones.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf known_hosts* keyscan.txt ssh-error.txt .lm-state; mkdir -p .lm-state/tmp
T=.lm-state/tmp

gen() {  # gen TYPE NAME -> prints "TYPE BLOB"
  rm -f "$T/k" "$T/k.pub"
  ssh-keygen -q -t "$1" -N '' -C "$2" -f "$T/k" >/dev/null 2>&1 || exit 1
  awk '{print $1, $2}' "$T/k.pub"
}
oldE=$(gen ed25519 old); oldC=$(gen ecdsa old)
newE=$(gen ed25519 new); newC=$(gen ecdsa new)

# plain list: "names<TAB>type blob" one name per line (so hashing gives one line per name)
{
  for h in web-01.internal web-02.internal db-01.internal git-mirror.internal "[10.4.0.9]:2222" bastion.example.org; do
    printf '%s\t%s\n' "$h" "$(gen ed25519 "$h")"
  done
  printf '%s\t%s\n' "git.internal" "$oldE"
  printf '%s\t%s\n' "git.internal" "$oldC"
  printf '%s\t%s\n' "[10.4.0.7]:2222" "$oldE"
  printf '%s\t%s\n' "[10.4.0.7]:2222" "$oldC"
  printf '%s\t%s\n' "db-01.internal" "$(gen ecdsa db-01)"
} | awk -v seed="$RANDOM" 'BEGIN{srand(seed)} {print rand() "\t" $0}' | sort -n | cut -f2- > "$T/plain"

awk -F'\t' '{print $1 " " $2}' "$T/plain" > known_hosts
cp known_hosts "$T/hashed-in"
ssh-keygen -H -f known_hosts >/dev/null 2>&1; rm -f known_hosts.old
# line i of known_hosts is the hashed version of line i of plain
paste -d'#' "$T/plain" known_hosts | awk -F'#' '{ split($1, a, "\t"); print a[1] "\t" $2 }' > "$T/map"
# lines to keep: everything not for git.internal or the IP alias; old = the others
awk -F'\t' '$1 != "git.internal" && $1 != "[10.4.0.7]:2222" { print $2 }' "$T/map" > .lm-state/keep
awk -F'\t' '$1 == "git.internal" || $1 == "[10.4.0.7]:2222" { print $2 }' "$T/map" > .lm-state/old-lines
printf '%s\n%s\n' "${oldE#* }" "${oldC#* }" > .lm-state/old-blobs
printf '%s\n%s\n' "${newE#* }" "${newC#* }" > .lm-state/new-blobs

cat > keyscan.txt <<KS
# git.internal:22 SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.5
git.internal $newE
# git.internal:22 SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.5
git.internal $newC
KS
line=$(grep -n "$(ssh-keygen -F git.internal -f known_hosts | awk '/^[^#]/ {print $3; exit}')" known_hosts | head -1 | cut -d: -f1)
cat > ssh-error.txt <<ERR
\$ ssh git@git.internal
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
Please contact your system administrator.
Add correct host key in known_hosts to get rid of this message.
Offending key for IP in known_hosts:${line:-1}
Host key verification failed.
ERR
rm -rf "$T"
