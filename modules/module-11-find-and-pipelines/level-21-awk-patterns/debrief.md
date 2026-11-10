# Who Is Eating The Web Server?

## Why it works
An awk program is a list of `pattern { action }` pairs; the action runs only
for lines where the pattern is true. `$1 == "www-data"` compares the whole
field, so neither the truncated `www-dep+` user nor root's
`sudo -u www-data ...` slipped in. `$4 > 5` compares numbers (5.0 is not more
than 5). `$8 ~ /^[DZ]/` matches the state letter whatever flags follow (`s`
session leader, `<` high priority, `+` foreground). And because awk splits on
blanks, the command line is fields 11 to NF, which the loop glues back together.

## Common mistakes
- `print $2, $11`: "php-fpm: pool www" becomes "php-fpm:", and every
  argument of the artisan commands is lost.
- `grep www-data`: matches the word anywhere, including another user's
  command line.
- `$8 == "D"`: misses `Ds`, `D<`, `D+`, `Z+`.

## Learn next
Ask ps for exactly the columns you need instead of parsing `ps aux`:
`ps -eo pid,stat,user,%mem,args --no-headers` (GNU) puts the command last
and never truncates the user name with `-o user:20`. D-state processes cannot
be killed, not even with SIGKILL: they wait for the I/O (here, a hanging NFS
mount). Zombies disappear when their parent reaps them or exits; find the
parent with `ps -o ppid= -p PID`.
