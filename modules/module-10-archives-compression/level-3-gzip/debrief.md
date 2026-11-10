# Disk at 92%

## Why it works
`gzip FILE` writes `FILE.gz` and removes `FILE` once the compressed copy is
complete, so the space is freed right away. Bash expands `app.log.{2..12}` to
eleven names before gzip runs, which keeps the live `app.log` and the
delaycompress file `app.log.1` out of the list. Text logs compress very well,
often to a tenth of their size; `gzip -l` shows the ratio.

## Common mistakes
- `gzip logs/app.log*` compresses the file the app is writing. The app keeps
  writing to the deleted file (the space is not freed) and the new log is lost
  until a restart.
- `app.log.[2-9]` matches one character, so 10 to 12 stay plain; `app.log.1*`
  also matches `app.log.1`.
- A file that is still open by a process does not free its space when it is
  deleted. `lsof +L1` lists such deleted-but-open files.

## Learn next
`zcat`, `zless` and `zgrep` read `.gz` logs without unpacking them. `gzip -k`
keeps the original, and `pigz` compresses with all CPU cores.
