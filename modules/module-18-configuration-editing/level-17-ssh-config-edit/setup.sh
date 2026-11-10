#!/bin/bash
# db-hosts.txt: six hosts with a user, port and key each (shuffled per setup). The starting
# config has "Host *" with User/ForwardAgent at the top (first value wins) and a gitlab.corp
# block that therefore never gets its own user.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p home/.ssh/keys .lm-state

users=(dbadmin pgops ora_ro reports etl backup dba_lead sre)
keys=(db_ed25519 pg_ed25519 ora_rsa reports_ed25519 etl_ed25519 backup_rsa lead_ed25519 sre_ed25519)
idx=($(printf '%s\n' 0 1 2 3 4 5 6 7 | sort -R))
: > db-hosts.txt
for n in 1 2 3 4 5 6; do
  i=${idx[n-1]}
  port=22
  if [ $((RANDOM % 3)) = 0 ]; then port=$((2200 + RANDOM % 50)); fi
  printf '%s %s %s keys/%s\n' "db-$n" "${users[i]}" "$port" "${keys[i]}" >> db-hosts.txt
done
# at least one host on a non-default port, so Port cannot be skipped
if ! awk '$3 != 22 { f = 1 } END { exit !f }' db-hosts.txt; then
  sed 's/^\(db-3 [^ ]* \)22/\12222/' db-hosts.txt > db-hosts.new && mv db-hosts.new db-hosts.txt
fi
for k in "${keys[@]}" bastion github gitlab; do : > "home/.ssh/keys/${k##*/}"; chmod 600 "home/.ssh/keys/${k##*/}"; done

cat > home/.ssh/config <<'CONF'
# ~/.ssh/config - started by Dana, never finished
Host *
    User deploy
    ForwardAgent yes
    ServerAliveInterval 30

Host gitlab.corp
    User git
    IdentityFile ~/.ssh/keys/gitlab

Host db-1
    HostName db-1.corp.internal
CONF
cp home/.ssh/config .lm-state/config.orig
cat > README.txt <<'TXT'
Layout: home/.ssh/config is the file to write; keys are in home/.ssh/keys/ (names as in db-hosts.txt,
plus bastion, github, gitlab). db-hosts.txt: host user port key.
Test it without connecting:  HOME=$SANDBOX/home ssh -G -F home/.ssh/config db-3
TXT
