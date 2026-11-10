#!/bin/bash
# etc/sudoers.d/ holds the rules of six teams. Exactly one rule per team file grants a way
# to become root (less / vim shell escapes, a wildcarded systemctl, tar with a wildcard,
# find via a Cmnd_Alias, a script owned by the deploy user). Every file also has safe rules
# that must survive (sudoedit, exact systemctl reload, rules that run as another user ...).
# The service name is random. 99-contractor.disabled is ignored by sudo (its name has a
# dot) and therefore NOT a finding. ownership.txt is a stat listing of the scripts the
# rules mention (a sandbox cannot chown): the validator uses it to tell root-owned
# wrappers from user-owned scripts. .lm-state/expected holds the original file:line of the
# six dangerous rules, .lm-state/safe the (who|command) pairs that must remain.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf etc ownership.txt escalations.txt .lm-state; mkdir -p etc/sudoers.d .lm-state
svcs=(app billing shop); svc=${svcs[RANDOM % 3]}
D=etc/sudoers.d
: > .lm-state/expected; : > .lm-state/safe
# lead N : N random comment lines so line numbers differ per run
lead() { local i n=$((1 + RANDOM % 4)); for ((i = 0; i < n; i++)); do echo "# $(printf '%s' "${1}") note $((RANDOM % 900 + 100))"; done; }
# rule FILE who|dangerous? text : append and record
add() { # file kind text    (kind: bad|safe)
  printf '%s\n' "$3" >> "$1"
  if [ "$2" = bad ]; then echo "$1:$(grep -nxF -- "$3" "$1" | tail -1 | cut -d: -f1)" >> .lm-state/expected; fi
}

cat > etc/sudoers <<'MAIN'
# /etc/sudoers (managed by the platform team)
Defaults	env_reset
Defaults	mail_badpass
root	ALL=(ALL:ALL) ALL
%sudo	ALL=(ALL:ALL) ALL
@includedir /etc/sudoers.d
MAIN

cat > $D/00-defaults <<'EOF2'
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Defaults logfile=/var/log/sudo.log
EOF2

# --- web: less on a log is a shell escape (!sh) -------------------------------------
f=$D/10-web; { lead web; echo "Cmnd_Alias NGINX_CTL = /usr/bin/systemctl reload nginx.service, /usr/bin/systemctl restart nginx.service"; } > $f
add $f safe "%web ALL=(root) NGINX_CTL"
add $f bad  "%web ALL=(root) NOPASSWD: /usr/bin/less /var/log/nginx/error.log"
add $f safe "%web ALL=(root) sudoedit /etc/nginx/conf.d/site.conf"
echo "%web|/usr/bin/systemctl reload nginx.service" >> .lm-state/safe
echo "%web|/usr/bin/systemctl restart nginx.service" >> .lm-state/safe
echo "%web|sudoedit /etc/nginx/conf.d/site.conf" >> .lm-state/safe

# --- dba: vim on a config file is a shell escape ---------------------------------------
f=$D/20-dba; lead dba > $f
add $f safe "%dba ALL=(postgres) NOPASSWD: /usr/bin/pg_dump orders"
add $f bad  "%dba ALL=(root) /usr/bin/vim /etc/postgresql/16/main/postgresql.conf"
echo "%dba|/usr/bin/pg_dump orders" >> .lm-state/safe

# --- ops: "restart SVC*" looks narrow, but sudo's * also matches spaces and further arguments --
f=$D/30-ops; lead ops > $f
add $f bad  "%ops ALL=(root) /usr/bin/systemctl restart $svc*"
add $f safe "%ops ALL=(root) /usr/sbin/logrotate -f /etc/logrotate.d/$svc"
echo "%ops|/usr/sbin/logrotate -f /etc/logrotate.d/$svc" >> .lm-state/safe

# --- backup: tar with a wildcard accepts --checkpoint-action=exec=... --------------------------
f=$D/40-backup; lead backup > $f
add $f safe "%backup ALL=(root) /usr/bin/du -sh /srv/data"
add $f bad  "%backup ALL=(root) NOPASSWD: /usr/bin/tar -czf /backup/*.tgz /srv/data"
echo "%backup|/usr/bin/du -sh /srv/data" >> .lm-state/safe

# --- dev: find hidden behind a Cmnd_Alias (find -exec runs anything as root) ----------------------
f=$D/50-dev; { lead dev; echo "Cmnd_Alias LOGVIEW = /usr/bin/find /var/log/$svc -name *.log"; } > $f
add $f safe "%dev ALL=(app) NOPASSWD: /usr/local/bin/app-console"
add $f bad  "%dev ALL=(root) NOPASSWD: LOGVIEW"
echo "%dev|/usr/local/bin/app-console" >> .lm-state/safe

# --- deploy: a safe-looking script that the deploy user can edit ------------------------------------
f=$D/60-deploy; lead deploy > $f
add $f bad  "%deploy ALL=(root) NOPASSWD: /opt/deploy.sh"
add $f safe "%deploy ALL=(root) /usr/bin/systemctl reload $svc.service"
echo "%deploy|/usr/bin/systemctl reload $svc.service" >> .lm-state/safe

# --- sudo ignores files whose name contains a dot: not an active rule -----------------------------------
cat > $D/99-contractor.disabled <<'EOF2'
# contractor access ended 2023, file kept for the audit trail
contractor ALL=(ALL) NOPASSWD: ALL
EOF2

cat > ownership.txt <<'EOF2'
# stat -c '%A %U %G %n', collected on the server
-rwxr-xr-x root root /usr/local/sbin/backup-home
-rwxr-xr-x root root /usr/local/sbin/deploy-release
-rwxr-xr-x root root /usr/local/bin/app-console
-rwxrwxr-x deploy deploy /opt/deploy.sh
EOF2
echo "$svc" > .lm-state/svc
( cd etc && sha256sum sudoers ) > .lm-state/main.sha
sha256sum < ownership.txt > .lm-state/own.sha
