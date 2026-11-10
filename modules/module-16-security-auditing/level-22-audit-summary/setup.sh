#!/bin/bash
# host/ is a small mock server tree. Five kinds of findings are mixed with look-alikes:
#   world-writable   regular files with the others-write bit (decoys: 664 files, a 1777 dir, a symlink)
#   unexpected-suid  setuid/setgid regular files not in host/etc/suid-baseline.txt (decoys: baseline
#                    entries, a setgid directory)
#   weak-key-mode    private keys (PRIVATE KEY header, any name or place) not mode 600 (decoy: .pub files)
#   sshd-setting     effective sshd values that break the policy, as the mock sshd -T prints them
#                    (a drop-in that wins, an omitted keyword with a bad default, a Match block that
#                    -T without -C ignores)
#   plaintext-secret password/api_key/secret assignments with a real value under host/etc and host/home
#                    (decoys: <placeholders>, ${VARS}, empty values, password_policy, a file outside scope)
# Which candidates are bad is random. The expected set is recorded while the files are made.
# host/ must not change: a tree hash is stored for the validator.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf host bin audit.tsv categories.txt policy.txt .lm-state; mkdir -p .lm-state bin
MOCK="$(cd "$(dirname "$0")/../../../mocks/security" && pwd)"
cp "$MOCK/sshd" bin/sshd; chmod 755 bin/sshd
E=.lm-state/expected; : > "$E"
H=host
mkdir -p $H/etc/ssh/sshd_config.d $H/etc/app $H/etc/cron.d $H/usr/bin $H/usr/local/bin $H/bin $H/opt/app $H/opt/tools \
         $H/var/www/html/uploads $H/srv/shared $H/tmp $H/home/alice/.ssh $H/home/bob/.ssh $H/usr/share/doc/sample
chance() { [ $((RANDOM % 100)) -lt "$1" ]; }
rnd() { LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"; }
finding() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$E"; }
mk() { # path mode content
  mkdir -p "$(dirname "$1")"; printf '%s\n' "$3" > "$1"; chmod "$2" "$1"; }

printf '%s\n' world-writable unexpected-suid weak-key-mode sshd-setting plaintext-secret > categories.txt
cat > policy.txt <<'POL'
Audit policy (what counts as a finding). Paths are relative to the sandbox, like host/etc/...

world-writable    regular files under host/ that others can write. Directories and symlinks are not
                  findings. detail = octal mode, e.g. 666.
unexpected-suid   regular files under host/ with the setuid or setgid bit that are not listed in
                  host/etc/suid-baseline.txt. detail = octal mode, e.g. 4755.
weak-key-mode     private keys under host/ (a file whose text has a "-----BEGIN ... PRIVATE KEY-----"
                  line, whatever its name or place) whose mode is not 600. detail = octal mode.
sshd-setting      effective sshd settings, as `sshd -T` reports them for host/etc/ssh/sshd_config,
                  that break the policy: permitrootlogin must be no, passwordauthentication no,
                  x11forwarding no, maxauthtries at most 4. path = host/etc/ssh/sshd_config,
                  detail = keyword=value as sshd -T prints it (lower case keyword).
plaintext-secret  lines under host/etc and host/home that set password, api_key or secret (any case,
                  optional spaces around =) to a real value; empty values, <placeholders> and ${VARS}
                  do not count. detail = line=N (the line number in that file).

audit.tsv: one line per finding, three tab-separated fields: category, path, detail.
POL

# ---- world-writable ---------------------------------------------------------
ww=( "$H/etc/cron.d/cleanup|666|*/30 * * * * root /opt/app/cleanup.sh"
     "$H/opt/app/settings.local|662|debug=false"
     "$H/var/www/html/uploads/index.php|666|<?php // upload handler"
     "$H/srv/shared/data.csv|646|id,value"
     "$H/home/bob/.bashrc|666|# bob's bashrc" )
n=0; for e in "${ww[@]}"; do
  IFS='|' read -r p m c <<< "$e"
  if [ $n -lt 2 ] || chance 45; then mk "$p" "$m" "$c"; finding world-writable "$p" "$m"; else mk "$p" 644 "$c"; fi
  n=$((n + 1))
done
mk $H/opt/app/shared.conf 664 "group writable only"
mk $H/srv/shared/notes.txt 664 "group writable only"
chmod 1777 $H/tmp; chmod 777 $H/var/www/html/uploads; chmod 2775 $H/srv/shared
ln -s ../../etc/cron.d/cleanup $H/opt/app/cleanup-link

# ---- SUID / SGID ---------------------------------------------------------------
printf '%s\n' "$H/usr/bin/sudo" "$H/usr/bin/passwd" "$H/bin/mount" "$H/usr/bin/wall" > $H/etc/suid-baseline.txt
mk $H/usr/bin/sudo 4755 "#!fake sudo"; mk $H/usr/bin/passwd 4755 "#!fake passwd"; mk $H/bin/mount 4755 "#!fake mount"
mk $H/usr/bin/wall 2755 "#!fake wall"
mk $H/usr/bin/ls-helper 755 "#!fake"
su=( "$H/usr/local/bin/backup-helper|4755" "$H/opt/tools/.cache-shell|4755" "$H/opt/tools/rotate|6755" "$H/usr/bin/newgrp-x|2755" )
n=0; for e in "${su[@]}"; do
  IFS='|' read -r p m <<< "$e"
  if [ $n -lt 1 ] || chance 50; then mk "$p" "$m" "#!fake"; finding unexpected-suid "$p" "$m"; else mk "$p" 755 "#!fake"; fi
  n=$((n + 1))
done

# ---- private keys --------------------------------------------------------------
key() { printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nFAKE-%s (training data, not a key)\n-----END OPENSSH PRIVATE KEY-----\n' "$(rnd 30)"; }
keys=( "$H/etc/ssh/ssh_host_ed25519_key" "$H/etc/ssh/ssh_host_rsa_key" "$H/home/alice/.ssh/id_ed25519" "$H/home/bob/.ssh/id_rsa" "$H/home/bob/.ssh/deploy_key" "$H/opt/app/old-deploy.pem" )
bad=(644 640 660 604 644 664)
n=0; for p in "${keys[@]}"; do
  key > "$p"
  if [ $n -lt 2 ] || chance 40; then chmod "${bad[n]}" "$p"; finding weak-key-mode "$p" "${bad[n]}"; else chmod 600 "$p"; fi
  n=$((n + 1))
done
for p in $H/etc/ssh/ssh_host_ed25519_key.pub $H/home/alice/.ssh/id_ed25519.pub $H/home/bob/.ssh/id_rsa.pub; do
  printf 'ssh-ed25519 AAAAFAKE%s host\n' "$(rnd 20)" > "$p"; chmod 644 "$p"
done

# ---- sshd settings -------------------------------------------------------------------
# state per setting: good | main (bad value in the main file) | dropin (bad value in a drop-in that wins) | omit
declare -A want_bad=( [permitrootlogin]=yes [passwordauthentication]=yes [x11forwarding]=yes [maxauthtries]=$((5 + RANDOM % 4)) )
declare -A state
kws=(permitrootlogin passwordauthentication x11forwarding maxauthtries)
nbad=0
for k in "${kws[@]}"; do
  r=$((RANDOM % 100))
  if   [ $r -lt 35 ]; then state[$k]=good
  elif [ $r -lt 55 ]; then state[$k]=main
  elif [ $r -lt 80 ]; then state[$k]=dropin
  else state[$k]=omit; fi
  [ "$k" = x11forwarding ] && [ "${state[$k]}" = omit ] && state[$k]=good     # the default of x11forwarding is no
  [ "${state[$k]}" != good ] && nbad=$((nbad + 1))
done
[ $nbad -lt 2 ] && { state[permitrootlogin]=dropin; state[passwordauthentication]=omit; }
good_line() { case $1 in permitrootlogin) echo "PermitRootLogin no";; passwordauthentication) echo "PasswordAuthentication no";; x11forwarding) echo "X11Forwarding no";; maxauthtries) echo "MaxAuthTries 3";; esac; }
bad_line()  { case $1 in permitrootlogin) echo "PermitRootLogin yes";; passwordauthentication) echo "PasswordAuthentication yes";; x11forwarding) echo "X11Forwarding yes";; maxauthtries) echo "MaxAuthTries ${want_bad[maxauthtries]}";; esac; }
{
  echo "# /etc/ssh/sshd_config - audit target"
  echo "Include sshd_config.d/*.conf"
  echo "Port 22"
  echo "HostKey /etc/ssh/ssh_host_ed25519_key"
  for k in "${kws[@]}"; do
    case ${state[$k]} in good|dropin) good_line "$k" ;; main) bad_line "$k" ;; esac
  done
  echo "PubkeyAuthentication yes"
  echo "Subsystem sftp /usr/lib/openssh/sftp-server"
  printf '\n# CI runners\nMatch User deploy\n    PasswordAuthentication yes\n    MaxAuthTries 10\n'
} > $H/etc/ssh/sshd_config
{ echo "# cloud-init"; echo "UsePAM yes"; for k in "${kws[@]}"; do [ "${state[$k]}" = dropin ] && bad_line "$k"; done; } > $H/etc/ssh/sshd_config.d/50-cloud-init.conf
echo "ClientAliveInterval 120" > $H/etc/ssh/sshd_config.d/60-keepalive.conf
chmod 644 $H/etc/ssh/sshd_config $H/etc/ssh/sshd_config.d/*.conf
eff=$(python3 "$MOCK/sshd" -T -f $H/etc/ssh/sshd_config) || exit 1
while read -r k v; do
  case $k in
    permitrootlogin|passwordauthentication|x11forwarding) [ "$v" != no ] && finding sshd-setting $H/etc/ssh/sshd_config "$k=$v" ;;
    maxauthtries) [ "$v" -gt 4 ] && finding sshd-setting $H/etc/ssh/sshd_config "$k=$v" ;;
  esac
done <<< "$eff"

# ---- plaintext secrets -------------------------------------------------------------------
# put FILE leakline < filler : record line number
put() { local f=$1 leak=$2 L pos i; mapfile -t L; pos=$((RANDOM % (${#L[@]} + 1)))
  { for ((i = 0; i < pos; i++)); do printf '%s\n' "${L[i]}"; done; printf '%s\n' "$leak"
    for ((i = pos; i < ${#L[@]}; i++)); do printf '%s\n' "${L[i]}"; done; } > "$f"
  chmod 644 "$f"; finding plaintext-secret "$f" "line=$((pos + 1))"; }
put $H/etc/app/db.conf "password = Db-$(rnd 10)" <<'DOC'
[database]
host = db.internal
user = app
password_policy = rotate-90-days
DOC
put $H/home/bob/.env "API_KEY=ak_$(rnd 20)" <<'DOC'
EDITOR=vim
ENVIRONMENT=prod
DOC
if chance 60; then put $H/etc/app/mail.ini "Secret=$(rnd 16)" <<'DOC'
[mail]
relay = smtp.internal
DOC
else printf '[mail]\nrelay = smtp.internal\nsecret=${MAIL_SECRET}\n' > $H/etc/app/mail.ini; chmod 644 $H/etc/app/mail.ini; fi
printf '[template]\npassword=<your-password-here>\napi_key=\nsecret = ${APP_SECRET}\n' > $H/etc/app/example.ini; chmod 644 $H/etc/app/example.ini
printf 'export EDITOR=vim\nalias ll="ls -l"\n' > $H/home/alice/.profile; chmod 644 $H/home/alice/.profile
printf '[sample]\npassword=hunter2\n' > $H/usr/share/doc/sample/sample.conf; chmod 644 $H/usr/share/doc/sample/sample.conf   # out of scope

LC_ALL=C sort -u "$E" -o "$E"
( find $H -printf '%p %y %m\n'; find $H -type f -exec sha256sum {} + ) | LC_ALL=C sort > .lm-state/tree
