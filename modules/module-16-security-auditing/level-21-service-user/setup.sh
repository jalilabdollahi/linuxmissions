#!/bin/bash
# reportd runs as the login user jalil (bash shell) and everything under opt/reportd is
# writable by that user, config.ini and one more file by everybody. The fake root is the
# sandbox: etc/passwd and etc/group (jalil = the real uid/gid of whoever plays), the shared
# accounts mock (useradd, usermod, groupadd, getent), the shared systemd-analyze mock, and two
# level-local helpers: chown (records ownership in .lm/owners, since a sandbox cannot
# chown) and reportd-check (a dry run of the unit under its sandboxing settings).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
M="$(cd "$HERE/../../../mocks" && pwd)"
rm -rf etc opt var bin .lm .lm-state; mkdir -p etc/systemd/system opt/reportd/lib opt/reportd/templates var/lib/reportd bin .lm-state
for t in useradd usermod groupadd getent; do cp "$M/accounts/$t" bin/$t; done
cp "$M/systemd/systemd-analyze" bin/systemd-analyze
cp "$HERE/chown" bin/chown; cp "$HERE/reportd-check" bin/reportd-check; chmod 755 bin/*

uid=$(id -u); gid=$(id -g)
cat > etc/passwd <<PW
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
sshd:x:105:65534::/run/sshd:/usr/sbin/nologin
jalil:x:$uid:$gid:Jalil Abdollahi:/home/jalil:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
PW
cat > etc/group <<GR
root:x:0:
daemon:x:1:
www-data:x:33:
jalil:x:$gid:
nogroup:x:65534:
GR
printf '# defaults for the mock\nUID_MIN 1000\nUID_MAX 60000\nSYS_UID_MIN 100\nSYS_UID_MAX 999\nGID_MIN 1000\nGID_MAX 60000\nSYS_GID_MIN 100\nSYS_GID_MAX 999\n' > etc/login.defs
cp etc/passwd .lm-state/passwd.orig

cat > etc/systemd/system/reportd.service <<'UNIT'
[Unit]
Description=Nightly report generator
After=network.target

[Service]
Type=simple
User=jalil
ExecStart=/opt/reportd/run.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

cat > opt/reportd/run.sh <<'RUN'
#!/bin/bash
# reportd: renders the nightly report from config.ini and keeps its state in /var/lib/reportd
. /opt/reportd/lib/render.sh
render_report /opt/reportd/config.ini /var/lib/reportd
RUN
printf '# helper functions\nrender_report() { echo "rendering from $1 into $2"; }\n' > opt/reportd/lib/render.sh
printf '[report]\nrecipients = ops@example.com\nformat = csv\n' > opt/reportd/config.ini
printf '<h1>{{title}}</h1>\n' > opt/reportd/templates/daily.html
printf '{"last_run": "2026-11-09"}\n' > var/lib/reportd/state.json
printf 'date,rows\n2026-11-09,214\n' > var/lib/reportd/report.csv

chmod 755 opt opt/reportd opt/reportd/lib opt/reportd/templates var var/lib var/lib/reportd etc etc/systemd etc/systemd/system
chmod 775 opt/reportd/run.sh
chmod 664 opt/reportd/lib/render.sh opt/reportd/templates/daily.html
chmod 666 opt/reportd/config.ini
chmod 644 var/lib/reportd/state.json var/lib/reportd/report.csv
# one more world-writable spot, random: a file in lib/ or the templates directory
if [ $((RANDOM % 2)) -eq 0 ]; then chmod 666 opt/reportd/lib/render.sh; else chmod 777 opt/reportd/templates; fi
