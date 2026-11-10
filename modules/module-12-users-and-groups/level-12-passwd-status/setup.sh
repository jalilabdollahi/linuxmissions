#!/bin/bash
# Audit of password states on app-04. etc/shadow field 2 decides: empty = NP (no
# password), a leading ! or * = L (locked, hash kept if it follows the !), anything
# else = P. Which person gets which state is random. Traps: `*` and `!` and `!!`
# are all locked, `!$y$...` keeps its hash but is locked, an empty field on a
# service account (ftp) and on one person is the critical finding.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

y='$y$j9T$h7cV0sQ1pYw3Zk5nRb2Ld1$Wm8uTq4eXJfG0aHcP9oK6iDsB3yNvLrE2zUt5wA1xC7'
s='$6$Qf3kL9aZ$G1mQ8rTn4xVjP0cDhU2sYw7bKe5oLzN3iA6tRfXq9uWvHdJ1mCpS4yBgE8kZ0nTaV2lOr5xQ7wDfU3hJiM6p/'
m='$1$abcd1234$9sJkLmNoPqRsTuVwXyZ0a1'

people=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); n = split("anya bruno cleo dario esme felix gita hamid", a, " ")
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t }
  for (i = 1; i <= n; i++) print a[i] }')
fields=("$y" "$s" "$m" "!" "!!" "!$y" "*" "")

{
  echo "root:$y:20100:0:99999:7:::"
  for u in daemon bin sys sync www-data nobody; do echo "$u:*:19800:0:99999:7:::"; done
  echo "sshd:!:19800:0:99999:7:::"
  echo "messagebus:!:19800:0:99999:7:::"
  echo "ftp::19800:0:99999:7:::"
} > etc/shadow
{
  echo 'root:x:0:0:root:/root:/bin/bash'
  echo 'daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin'
  echo 'bin:x:2:2:bin:/bin:/usr/sbin/nologin'
  echo 'sys:x:3:3:sys:/dev:/usr/sbin/nologin'
  echo 'sync:x:4:65534:sync:/bin:/bin/sync'
  echo 'www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin'
  echo 'nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin'
  echo 'sshd:x:105:65534::/run/sshd:/usr/sbin/nologin'
  echo 'messagebus:x:101:101::/nonexistent:/usr/sbin/nologin'
  echo 'ftp:x:116:124:ftp daemon:/srv/ftp:/usr/sbin/nologin'
} > etc/passwd

uid=1000; i=0
for u in $people; do
  echo "$u:${fields[$i]}:$((20050 + i * 20)):0:99999:7:::" >> etc/shadow
  echo "$u:x:$uid:$uid:${u^}:/home/$u:/bin/bash" >> etc/passwd
  uid=$((uid + 1)); i=$((i + 1))
done

cksum etc/shadow etc/passwd > .lm-state/inputs
