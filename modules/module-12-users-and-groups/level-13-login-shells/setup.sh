#!/bin/bash
# Login-shell policy on app-04. Policy: (1) service accounts (UID 1-999 and nobody,
# but not root and not sync) get no interactive shell; a shell that is already
# /usr/sbin/nologin or /bin/false stays; any other becomes /usr/sbin/nologin.
# (2) people (UID 1000-59999) keep a shell that is in etc/shells or is an explicit
# no-login shell (a disabled person stays disabled); anything else becomes /bin/bash.
# Which accounts are wrong is random. Traps: root and sync (/bin/sync) are exceptions;
# /bin/zsh is not in etc/shells; "/bin/bash " (trailing space) is not /bin/bash;
# a person with nologin must not be "fixed" to bash; the NIS "+::::::" line stays.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc bin .lm-state
M="$(cd "$(dirname "$0")/../../../mocks/accounts" && pwd)"
cp "$M/usermod" bin/

cat > etc/shells <<'EOT'
# /etc/shells: valid login shells
/bin/sh
/bin/bash
/usr/bin/bash
/bin/rbash
/usr/bin/rbash
/usr/bin/dash
/usr/bin/tmux
EOT

# four of the nine ordinary service accounts have a login shell by mistake
bad=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); n = split("daemon bin sys games lp mail www-data backup postgres", a, " ")
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t }
  print a[1], a[2], a[3], a[4] }')
badshell=(/bin/bash /bin/sh /usr/bin/dash /bin/bash)
shell_of() {  # shell_of ACCOUNT: nologin unless it is one of the four picked
  local k=0 b
  for b in $bad; do
    [ "$b" = "$1" ] && { echo "${badshell[$k]}"; return; }
    k=$((k + 1))
  done
  echo /usr/sbin/nologin
}

# three people have the three bad shells, three have good ones; random order
pshell=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); split("/bin/zsh|/bin/bash |/usr/sbin/nologin|/bin/bash|/usr/bin/tmux|/bin/sh", a, "|")
  for (i = 6; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t }
  for (i = 1; i <= 6; i++) print a[i] }')

{
  echo 'root:x:0:0:root:/root:/bin/bash'
  echo "daemon:x:1:1:daemon:/usr/sbin:$(shell_of daemon)"
  echo "bin:x:2:2:bin:/bin:$(shell_of bin)"
  echo "sys:x:3:3:sys:/dev:$(shell_of sys)"
  echo 'sync:x:4:65534:sync:/bin:/bin/sync'
  echo "games:x:5:60:games:/usr/games:$(shell_of games)"
  echo "lp:x:7:7:lp:/var/spool/lpd:$(shell_of lp)"
  echo "mail:x:8:8:mail:/var/mail:$(shell_of mail)"
  echo "www-data:x:33:33:www-data:/var/www:$(shell_of www-data)"
  echo "backup:x:34:34:backup:/var/backups:$(shell_of backup)"
  echo 'sshd:x:105:65534::/run/sshd:/usr/sbin/nologin'
  echo "postgres:x:115:123:PostgreSQL administrator,,,:/var/lib/postgresql:$(shell_of postgres)"
  echo 'nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin'
  uid=1000
  for u in alice bruno carol dmitri erin farid; do
    s=$(printf '%s\n' "$pshell" | sed -n "$((uid - 999))p")
    echo "$u:x:$uid:$uid:${u^}:/home/$u:$s"
    uid=$((uid + 1))
  done
  echo '+::::::'
} > etc/passwd

cat > etc/group <<'EOT'
root:x:0:
nogroup:x:65534:
EOT
cat > etc/shadow <<'EOT'
root:*:19800:0:99999:7:::
EOT
cp etc/passwd .lm-state/passwd.orig
cksum etc/shells .lm-state/passwd.orig > .lm-state/inputs
