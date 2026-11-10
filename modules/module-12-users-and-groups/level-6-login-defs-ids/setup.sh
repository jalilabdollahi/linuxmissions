#!/bin/bash
# Next IDs on app-04: etc/login.defs with a non-default SYS_UID_MAX (999 or 899
# at random), a passwd/group with gaps and out-of-range IDs. Traps: lena's UID
# is the highest regular UID + 1 (not the first gap), but that number is already
# a GID (group "contractors"); system accounts count down from the lowest used
# system ID; classic accounts under 100, 999/998 when SYS_UID_MAX is 899, 62001
# and 65534 are outside the ranges that matter.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

smax=$((899 + (RANDOM % 2) * 100))
cat > etc/login.defs <<EOT
#
# /etc/login.defs - site-specific configuration for the shadow login suite.
# app-04, managed by ansible
#
MAIL_DIR        /var/mail
ENV_PATH        PATH=/usr/local/bin:/usr/bin:/bin
UMASK           022
PASS_MAX_DAYS   99999
PASS_MIN_DAYS   0
PASS_WARN_AGE   7

# Min/max values for automatic uid selection in useradd
#UID_MIN         500
UID_MIN          1000
UID_MAX         60000
# System accounts
SYS_UID_MIN       100
SYS_UID_MAX       $smax

# Min/max values for automatic gid selection in groupadd
GID_MIN          1000
GID_MAX         60000
# System accounts
SYS_GID_MIN       100
SYS_GID_MAX       $smax

USERGROUPS_ENAB yes
CREATE_HOME     no
EOT

# lowest used system UID (random), then a few more above it
m=$((smax - 14 - RANDOM % 6))
gm=$((m - 3 - RANDOM % 3))
hi=$((1006 + RANDOM % 3))     # highest regular UID

{
  echo 'root:x:0:0:root:/root:/bin/bash'
  echo 'daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin'
  echo 'bin:x:2:2:bin:/bin:/usr/sbin/nologin'
  echo 'sys:x:3:3:sys:/dev:/usr/sbin/nologin'
  echo 'sync:x:4:65534:sync:/bin:/bin/sync'
  echo 'man:x:6:12:man:/var/cache/man:/usr/sbin/nologin'
  echo 'mail:x:8:8:mail:/var/mail:/usr/sbin/nologin'
  echo 'www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin'
  echo 'backup:x:34:34:backup:/var/backups:/usr/sbin/nologin'
  echo "systemd-network:x:$m:$gm:systemd Network Management:/:/usr/sbin/nologin"
  echo "systemd-resolve:x:$((m + 1)):$((gm + 1)):systemd Resolver:/:/usr/sbin/nologin"
  echo "messagebus:x:$((m + 3)):$((gm + 2)):D-Bus:/nonexistent:/usr/sbin/nologin"
  echo "sshd:x:$((m + 4)):65534::/run/sshd:/usr/sbin/nologin"
  echo "chrony:x:$((m + 6)):$((gm + 4)):Chrony:/var/lib/chrony:/usr/sbin/nologin"
  echo "node-exporter:x:$((m + 8)):$((gm + 6)):Prometheus node exporter:/var/lib/node_exporter:/usr/sbin/nologin"
  if [ "$smax" = 899 ]; then
    echo 'systemd-timesync:x:998:998:systemd Time Synchronization:/:/usr/sbin/nologin'
    echo 'gitlab-runner:x:999:999:GitLab Runner:/home/gitlab-runner:/bin/bash'
  fi
  echo 'alice:x:1000:1000:Alice Moreau:/home/alice:/bin/bash'
  echo 'bruno:x:1001:1001:Bruno Costa:/home/bruno:/bin/bash'
  echo 'chen:x:1003:1003:Chen Wei:/home/chen:/bin/bash'
  echo 'dara:x:1004:1004:Dara Okafor:/home/dara:/bin/bash'
  echo "emil:x:$hi:$hi:Emil Novak:/home/emil:/bin/bash"
  echo 'importer:x:62001:62001:LDAP import:/home/importer:/usr/sbin/nologin'
  echo 'nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin'
} > etc/passwd

{
  echo 'root:x:0:'
  echo 'daemon:x:1:'
  echo 'bin:x:2:'
  echo 'sys:x:3:'
  echo 'adm:x:4:alice'
  echo 'mail:x:8:'
  echo 'man:x:12:'
  echo 'sudo:x:27:alice'
  echo 'www-data:x:33:'
  echo 'backup:x:34:'
  echo "systemd-network:x:$gm:"
  echo "systemd-resolve:x:$((gm + 1)):"
  echo "messagebus:x:$((gm + 2)):"
  echo "chrony:x:$((gm + 4)):"
  echo "telemetry:x:$((m - 1)):"
  echo "node-exporter:x:$((gm + 6)):"
  if [ "$smax" = 899 ]; then echo 'systemd-timesync:x:998:'; echo 'gitlab-runner:x:999:'; fi
  echo 'alice:x:1000:'
  echo 'bruno:x:1001:'
  echo 'chen:x:1003:'
  echo 'dara:x:1004:'
  echo "emil:x:$hi:"
  echo "contractors:x:$((hi + 1)):chen"
  echo 'shared:x:1500:alice,bruno,chen,dara,emil'
  echo 'importer:x:62001:'
  echo 'nogroup:x:65534:'
} > etc/group

cksum etc/login.defs etc/passwd etc/group > .lm-state/inputs
