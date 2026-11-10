#!/bin/bash
# Who Logs In? A copy of web-03's etc/passwd and etc/shells. The people and
# their shells change on every run. Traps: nobody (65534), a person whose
# shell is nologin or false, gitlab-runner (UID 999 with bash), a NIS "+"
# line whose empty UID field reads as 0, and a second UID 0 account "toor".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

cat > etc/shells <<'EOF'
# /etc/shells: valid login shells
/bin/sh
/usr/bin/sh
/bin/bash
/usr/bin/bash
/bin/rbash
/usr/bin/rbash
/usr/bin/dash
/bin/zsh
/usr/bin/zsh
/usr/bin/tmux
EOF

# Pool of people; a random 8 of them get accounts, in random order.
people=$(awk -v seed="$RANDOM" 'BEGIN {
  n = split("anya:Anya Petrova|marco:Marco Bellini|tkaur:Tejinder Kaur|lwong:Lena Wong|jbrooks:Jamal Brooks|" \
            "fatima:Fatima Haddad|okeefe:Sean O'\''Keefe|rsato:Rin Sato|mdiaz:Maria Diaz|pnovak:Pavel Novak|" \
            "ychen:Yu Chen|ahmed:Ahmed Saleh", a, "|")
  srand(seed)
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t }
  for (i = 1; i <= 8; i++) print a[i]
}')

# Shells: two people lost their login (nologin / false), one uses zsh, the rest bash.
shells=$(awk -v seed="$RANDOM" 'BEGIN {
  split("/usr/sbin/nologin /bin/false /bin/zsh /bin/bash /bin/bash /bin/bash /bin/bash /bin/bash", s, " ")
  srand(seed)
  for (i = 8; i > 1; i--) { j = int(rand() * i) + 1; t = s[i]; s[i] = s[j]; s[j] = t }
  for (i = 1; i <= 8; i++) print s[i]
}')

humans=""
uid=1000
i=0
while IFS= read -r p; do
  i=$((i + 1))
  login=${p%%:*}; full=${p#*:}
  sh=$(printf '%s\n' "$shells" | sed -n "${i}p")
  humans="$humans$login:x:$uid:$uid:$full,,,:/home/$login:$sh
"
  uid=$((uid + 1 + RANDOM % 3))
done <<< "$people"

toor='toor:x:0:0:root (BSD habit),,,:/root:/bin/bash'
spot=$((RANDOM % 4))

{
  echo 'root:x:0:0:root:/root:/bin/bash'
  [ $spot = 0 ] && echo "$toor"
  echo 'daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin'
  echo 'bin:x:2:2:bin:/bin:/usr/sbin/nologin'
  echo 'sys:x:3:3:sys:/dev:/usr/sbin/nologin'
  echo 'sync:x:4:65534:sync:/bin:/bin/sync'
  echo 'games:x:5:60:games:/usr/games:/usr/sbin/nologin'
  echo 'man:x:6:12:man:/var/cache/man:/usr/sbin/nologin'
  echo 'lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin'
  echo 'mail:x:8:8:mail:/var/mail:/usr/sbin/nologin'
  [ $spot = 1 ] && echo "$toor"
  echo 'news:x:9:9:news:/var/spool/news:/usr/sbin/nologin'
  echo 'uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin'
  echo 'proxy:x:13:13:proxy:/bin:/usr/sbin/nologin'
  echo 'www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin'
  echo 'backup:x:34:34:backup:/var/backups:/usr/sbin/nologin'
  echo 'list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin'
  echo 'irc:x:39:39:ircd:/run/ircd:/usr/sbin/nologin'
  echo '_apt:x:42:65534::/nonexistent:/usr/sbin/nologin'
  echo 'nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin'
  echo 'systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin'
  echo 'systemd-timesync:x:996:996:systemd Time Synchronization:/:/usr/sbin/nologin'
  [ $spot = 2 ] && echo "$toor"
  echo 'dhcpcd:x:100:65534:DHCP Client Daemon,,,:/usr/lib/dhcpcd:/bin/false'
  echo 'messagebus:x:101:101::/nonexistent:/usr/sbin/nologin'
  echo 'syslog:x:102:102::/nonexistent:/usr/sbin/nologin'
  echo 'systemd-resolve:x:991:991:systemd Resolver:/:/usr/sbin/nologin'
  echo 'sshd:x:105:65534::/run/sshd:/usr/sbin/nologin'
  echo 'gitlab-runner:x:999:999:GitLab Runner:/home/gitlab-runner:/bin/bash'
  echo 'postfix:x:106:111::/var/spool/postfix:/usr/sbin/nologin'
  [ $spot = 3 ] && echo "$toor"
  printf '%s' "$humans"
  echo '+::::::'
} > etc/passwd

# Fingerprint of the inputs, so the validator can tell if they were edited.
cksum etc/passwd etc/shells > .lm-state/inputs
