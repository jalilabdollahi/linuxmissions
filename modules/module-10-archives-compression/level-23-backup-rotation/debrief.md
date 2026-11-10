# Five Generations

## Why it works
Shifting has to start at the top: `.4 -> .5` first frees .4, then
`.3 -> .4` frees .3, and so on, so each move lands on a slot that was just
emptied. The ascending draft did `.1 -> .2` first, which overwrote
yesterday's backup with today's, and the copy then rippled up until every
generation was the same file. `rm -f` and `if [ -e ]` keep `set -e` happy
when a generation is missing, and the gap simply moves up with the others.

## Common mistakes
- Ascending order: after one run, .2 to .5 all hold the same content.
- `[ -e f ] && mv f g` as the last command of a script or function: when the
  test fails, the whole thing returns 1, so cron reports a failure.
- "Compacting" gaps (renumbering what is left): then .5 is no longer
  "five nights ago", and the retention promise breaks.

## Learn next
This is the numbering scheme logrotate uses (`rotate 5`), and
`savelog -c 5 FILE` from Debian's debianutils does the same for single
files. For backups by date instead of by number, keep `site-$(date +%F).tar.gz`
and prune with `find backups -mtime +5 -delete`.
