# Compress the Old Logs

## Why it works
`-mmin +10080` is "modified more than 10080 minutes (7 days) ago", and find
hands every match to `gzip` through `-exec gzip {} +`, which runs gzip once with
all the names as separate arguments, spaces and all. gzip replaces each file
with a `.gz` and keeps its timestamp.

## Common mistakes
- `-mtime +7`: find divides the age by 24 h and *drops the fraction* before
  comparing, so a 7.5-day-old log counts as 7 days and "+7" (more than 7) skips
  it. `-mtime +6` or `-mmin +10080` catches it.
- `for f in $(find ...); do gzip $f; done` splits `worker 2-....log` into two
  words and gzips nothing (or the wrong file).
- Leaving out `-name '*.log'` also compresses `heap-dump.txt`, `cron.log.1`, and
  tries to compress the existing `.gz` again.

## Learn next
`-exec CMD {} \;` runs the command once per file (needed when `{}` is not the
last argument), and `-ok` asks before each run. For real rotation, a
`/etc/logrotate.d/app` entry with `daily`, `rotate 14`, `compress` and
`delaycompress` does this job and more.
