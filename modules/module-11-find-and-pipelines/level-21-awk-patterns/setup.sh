#!/bin/bash
# Who Is Eating The Web Server? A `ps aux` snapshot of a busy web host with
# ~900 processes: PHP-FPM / Apache workers of www-data, a deploy user that ps
# shows truncated as www-dep+, a root process whose command line mentions
# www-data, %MEM values right at 5.0, and processes stuck in D or Z states
# with extra STAT flags. Random numbers on every setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function row(user, stat, mem, cmd,   vsz) {
  pid += (pid == 0) ? 1 : 1 + int(rand() * 40)
  vsz = (cmd ~ /^\[/) ? 0 : int(mem * 160000 + rand() * 90000 + 4000)
  printf "%-8s %7d %4.1f %4.1f %7d %6d %-8s %-4s %5s %6s %s\n", user, pid, rand() * (stat ~ /^R/ ? 90 : 3), mem, vsz, int(vsz * 0.6), (cmd ~ /^\[/ ? "?" : (rand() < 0.1 ? "pts/" int(rand() * 3) : "?")), stat, (rand() < 0.5 ? "Nov08" : sprintf("%02d:%02d", int(rand() * 10), int(rand() * 60))), sprintf("%d:%02d", int(rand() * 90), int(rand() * 60)), cmd
}
function m(lo, hi) { return lo + rand() * (hi - lo) }
BEGIN {
  srand(seed)
  print "USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND"
  pid = 0
  row("root", "Ss", 0.1, "/sbin/init splash")
  for (i = 0; i < 160; i++) row("root", (rand() < 0.8 ? "I<" : "S"), 0.0, "[kworker/" int(rand() * 16) ":" int(rand() * 3) "-events]")
  row("root", "Ss", 0.4, "/lib/systemd/systemd-journald")
  row("root", "Ss", 0.1, "/usr/sbin/cron -f -P")
  row("root", "Ssl", 0.3, "/usr/sbin/rsyslogd -n -iNONE")
  row("root", "Ss", 0.2, "sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups")
  row("root", "Ss", 0.9, "php-fpm: master process (/etc/php/8.3/fpm/php-fpm.conf)")
  row("root", "Ss", 0.3, "/usr/sbin/apache2 -k start")
  # the real thing: www-data workers, a few of them heavy
  for (i = 0; i < 420; i++) {
    r = rand()
    if (r < 0.06) mem = m(5.1, 14)
    else if (r < 0.09) mem = 5.0
    else mem = m(0.2, 4.9)
    c = rand()
    if (c < 0.55) cmd = "php-fpm: pool www"
    else if (c < 0.85) cmd = "/usr/sbin/apache2 -k start"
    else if (c < 0.95) cmd = "/usr/bin/php8.3 /var/www/shop/artisan queue:work redis --queue=mail,default --tries=3"
    else cmd = "/usr/bin/php8.3 /var/www/shop/artisan schedule:run --no-interaction"
    st = (rand() < 0.7) ? "S" : (rand() < 0.5 ? "R" : "Sl")
    if (rand() < 0.012) st = (rand() < 0.5) ? "D" : "Ds"
    row("www-data", st, mem, cmd)
    if (rand() < 0.01) row("www-data", (rand() < 0.5 ? "Z" : "Z+"), 0.0, "[php-fpm8.3] <defunct>")
  }
  # decoys: the deploy user (ps truncates names over 8 characters) and root
  for (i = 0; i < 6; i++) row("www-dep+", "S", m(5.5, 9), "/usr/bin/rsync --server -logDtpre.iLsfxCIvu . /var/www/releases/2026-11-10")
  for (i = 0; i < 3; i++) row("root", "S+", m(5.5, 8), "sudo -u www-data /usr/bin/php8.3 /var/www/shop/artisan migrate --force")
  for (i = 0; i < 40; i++) row("postgres", (rand() < 0.9 ? "Ss" : "Ds"), m(0.5, 9), "postgres: 16/main: shop shop 127.0.0.1(" int(40000 + rand() * 20000) ") idle")
  for (i = 0; i < 3; i++) row("redis", "Ssl", m(1, 7), "/usr/bin/redis-server 127.0.0.1:6379")
  # stuck I/O on the NFS backup mount, and zombies left by a broken script
  row("root", "D", 0.1, "/usr/bin/rsync -a --delete /var/www/shop/storage /mnt/nfs/backup/shop")
  row("root", "D<", 0.0, "[jbd2/dm-0-8]")
  row("backup", "D+", 0.4, "du -sh /mnt/nfs/backup")
  row("backup", "Zs", 0.0, "[sh] <defunct>")
  for (i = 0; i < 230; i++) row("root", (rand() < 0.9 ? "S" : "SN"), 0.0, "[" (rand() < 0.5 ? "ksoftirqd/" : "migration/") int(i / 2) "]")
  row("monitor", "S", 0.3, "/usr/bin/python3 /opt/agent/agent.py --tags=env:prod,role:web,state:D-tier")
  row("admin", "R+", 0.0, "ps aux")
}' > ps-aux.txt

cksum < ps-aux.txt > .lm-state/ps.sum
