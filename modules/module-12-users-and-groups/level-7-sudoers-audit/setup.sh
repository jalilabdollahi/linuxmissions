#!/bin/bash
# Who is root on db-01? A copy of etc/sudoers, etc/sudoers.d/* and etc/group.
# Full root comes from: root, %sudo members, the User_Alias ADMINS (with a
# backslash continuation), %wheel (a drop-in), ci-runner and vendor (drop-ins).
# Traps: `#includedir` is a directive, not a comment; sudoers.d/90-ops.bak,
# 70-legacy.conf (contain a dot) and README~ are skipped by sudo; a rule limited
# to commands or to another runas user (postgres) is not full root; a rule for
# another host (db-02) does not apply; a commented-out rule is nothing.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc/sudoers.d .lm-state

cat > etc/group <<'EOF2'
root:x:0:
adm:x:4:alice,tomas
sudo:x:27:alice,dmitri,lena
wheel:x:1010:kai,noor
deploy:x:1021:wei,tomas
dba:x:1030:pavel,rosa
ops:x:1040:mallory,zoe,tomas
EOF2

cat > etc/sudoers <<'EOF2'
#
# This file MUST be edited with the 'visudo' command as root.
#
Defaults	env_reset
Defaults	mail_badpass
Defaults	secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Host alias specification

# User alias specification
User_Alias ADMINS = lena, omar, \
                    dmitri

# Cmnd alias specification
Cmnd_Alias DBTOOLS = /usr/bin/psql, /usr/bin/pg_dump, /usr/bin/pg_restore
Cmnd_Alias SERVICES = /usr/bin/systemctl restart postgresql, /usr/bin/systemctl status postgresql

# User privilege specification
root	ALL=(ALL:ALL) ALL

# Members of the admin group may gain root privileges
%sudo	ALL=(ALL:ALL) ALL

# Operations team lead, approved in CHG-4471
ADMINS	ALL=(ALL) ALL

# DBAs work as the postgres user only
%dba	ALL=(postgres) ALL

# tomas ALL=(ALL:ALL) ALL
%adm	ALL=(root) /usr/bin/journalctl, /usr/bin/less /var/log/*

# See sudoers(5) for more information on "#include" directives:

#includedir /etc/sudoers.d
EOF2
chmod 440 etc/sudoers

cat > etc/sudoers.d/10-wheel <<'EOF2'
# platform team
%wheel ALL=(ALL) NOPASSWD: ALL
EOF2
cat > etc/sudoers.d/20-deploy <<'EOF2'
# release automation: restart the app, nothing else
%deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart app, /usr/bin/systemctl status app
EOF2
cat > etc/sudoers.d/30-ci <<'EOF2'
# build agent deploys schema changes without a prompt
ci-runner ALL=(ALL) NOPASSWD: ALL
EOF2
cat > etc/sudoers.d/40-dba <<'EOF2'
%dba ALL=(ALL) DBTOOLS, SERVICES
EOF2
cat > etc/sudoers.d/50-hosts <<'EOF2'
# vendor support, only the hosts named here
vendor db-01 = (ALL) NOPASSWD: ALL
zoe    db-02 = (ALL) ALL
EOF2
cat > etc/sudoers.d/70-legacy.conf <<'EOF2'
legacy ALL=(ALL) ALL
EOF2
cat > etc/sudoers.d/90-ops.bak <<'EOF2'
# backup from the October change
%ops ALL=(ALL:ALL) ALL
EOF2
cat > etc/sudoers.d/README~ <<'EOF2'
mallory ALL=(ALL) NOPASSWD: ALL
EOF2
chmod 440 etc/sudoers.d/*

cksum etc/sudoers etc/group etc/sudoers.d/* > .lm-state/inputs
