#!/bin/bash
# Boot Without a GUI. default.target is an absolute symlink to graphical.target.
# Absolute targets dangle in the sandbox (they are rooted at the real "/"); that
# is correct for the real machine and must stay so. Trap: linking to the
# sandbox path "works" here and breaks on the real server.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
R=sysroot
mkdir -p $R/usr/lib/systemd/system $R/etc/systemd/system/multi-user.target.wants .lm-state
ln -sfn usr/lib $R/lib

cd $R/usr/lib/systemd/system
cat > multi-user.target <<'EOT'
[Unit]
Description=Multi-User System
Documentation=man:systemd.special(7)
Requires=basic.target
Conflicts=rescue.service rescue.target
After=basic.target rescue.service rescue.target
AllowIsolate=yes
EOT
cat > graphical.target <<'EOT'
[Unit]
Description=Graphical Interface
Documentation=man:systemd.special(7)
Requires=multi-user.target
Wants=display-manager.service
Conflicts=rescue.service rescue.target
After=multi-user.target rescue.service rescue.target display-manager.service
AllowIsolate=yes
EOT
cat > rescue.target <<'EOT'
[Unit]
Description=Rescue Mode
Requires=sysinit.target rescue.service
After=sysinit.target rescue.service
AllowIsolate=yes
EOT
cat > emergency.target <<'EOT'
[Unit]
Description=Emergency Mode
Requires=emergency.service
After=emergency.service
AllowIsolate=yes
EOT
cat > ssh.service <<'EOT'
[Unit]
Description=OpenBSD Secure Shell server
After=network.target
[Service]
ExecStart=/usr/sbin/sshd -D
[Install]
WantedBy=multi-user.target
EOT
cd "$SANDBOX/$R/etc/systemd/system"
ln -s /usr/lib/systemd/system/ssh.service multi-user.target.wants/ssh.service
ln -s /usr/lib/systemd/system/graphical.target default.target
cd "$SANDBOX"
( cd $R/usr/lib/systemd/system && cksum *.target ssh.service ) > .lm-state/units
ls -l $R/etc/systemd/system/multi-user.target.wants > .lm-state/wants
