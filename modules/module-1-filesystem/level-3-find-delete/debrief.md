# Spring Cleaning

## What you practiced
- `find -delete` combines search and removal in one atomic pass — no temp files or pipes needed
- `xargs` pipes `find` results into `rm` — handy for complex filtering before deletion
- Always **preview** with `find … -name "*.tmp"` before adding `-delete`

## Commands to remember
```bash
find /path -name "*.tmp" -delete           # delete all matching
find /path -name "*.log" -mtime +7 -delete # logs older than 7 days
find /path -name "*.tmp" | xargs rm -f     # alternative via xargs
find /path -empty -type f -delete          # remove empty files
```
