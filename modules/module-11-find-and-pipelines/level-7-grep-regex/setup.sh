#!/bin/bash
# Root Over SSH: 12 sshd_config files built from the Ubuntu stock file. Each
# host gets one variant (shuffled per run): commented lines, tabs, upper/lower
# case keywords, prohibit-password and friends, and duplicate settings where
# sshd uses the FIRST value it reads.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

hosts=(web-01 web-02 web-03 web-04 db-01 db-02 cache-01 lb-01 lb-02 ci-runner bastion mail-01)
order=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); for (i = 0; i < 12; i++) a[i] = i
  for (i = 11; i > 0; i--) { j = int(rand() * (i + 1)); t = a[i]; a[i] = a[j]; a[j] = t }
  for (i = 0; i < 12; i++) print a[i] }')

conf() {  # conf ROOTLINES ENDLINES
  cat <<CONF
# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

Port 22
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
#PermitRootLogin prohibit-password
$1
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

#PubkeyAuthentication yes

# Expect .ssh/authorized_keys2 to be disregarded by default in future.
#AuthorizedKeysFile	.ssh/authorized_keys .ssh/authorized_keys2

# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication yes
#PermitEmptyPasswords no

# Change to yes to enable challenge-response passwords (beware issues with
# some PAM modules and threads)
KbdInteractiveAuthentication no

UsePAM yes

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
X11Forwarding yes
#PrintMotd yes
#PrintLastLog yes
#TCPKeepAlive yes
#PermitUserEnvironment no
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem	sftp	/usr/lib/openssh/sftp-server
$2
# Example of overriding settings on a per-user basis
#Match User anoncvs
#	X11Forwarding no
#	AllowTcpForwarding no
#	PermitTTY no
#	ForceCommand cvs server
CONF
}

: > .lm-state/yes; : > .lm-state/why
k=0
for v in $order; do
  h=${hosts[$k]}; k=$((k + 1))
  mkdir -p "hosts/$h"
  case $v in
    0) r='PermitRootLogin yes'; e=''; ok=1; why='' ;;
    1) r='#PermitRootLogin yes'; e=''; ok=0; why="its only PermitRootLogin lines are comments, so the default (prohibit-password) applies" ;;
    2) r='PermitRootLogin prohibit-password'; e=''; ok=0; why="it sets prohibit-password: root may log in with a key only" ;;
    3) r=$'\tpermitrootlogin\tyes'; e=''; ok=1; why='' ;;
    4) r='PermitRootLogin no'; e=$'\n# temporary, for the migration (2025-06)\nPermitRootLogin yes'; ok=0; why="its first PermitRootLogin says no, and sshd keeps the first value it reads" ;;
    5) r='PermitRootLogin yes'; e=$'\n# hardening, ticket SEC-88\nPermitRootLogin no'; ok=1; why='' ;;
    6) r='PermitRootLogin without-password'; e=''; ok=0; why="without-password is the old name of prohibit-password" ;;
    7) r='# PermitRootLogin yes   (disabled 2025-03, see OPS-112)'; e=$'\nPermitRootLogin forced-commands-only'; ok=0; why="its yes line is a comment; the setting in effect is forced-commands-only" ;;
    8) r='PERMITROOTLOGIN yes'; e=''; ok=1; why='' ;;
    9) r=''; e=''; ok=0; why="it has no PermitRootLogin setting, so the default (prohibit-password) applies" ;;
    10) r=$'#PermitRootLogin no\nPermitRootLogin   yes'; e=''; ok=1; why='' ;;
    11) r=$'PermitRootLogin prohibit-password\nPermitEmptyPasswords yes'; e=''; ok=0; why="it sets prohibit-password (PermitEmptyPasswords is a different setting)" ;;
  esac
  conf "$r" "$e" > "hosts/$h/sshd_config"
  [ $ok = 1 ] && echo "$h" >> .lm-state/yes
  [ -n "$why" ] && printf '%s\t%s\n' "$h" "$why" >> .lm-state/why
done
LC_ALL=C sort -o .lm-state/yes .lm-state/yes
