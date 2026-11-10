# Weekly Bounce Report

## Why it works
Each stage answers one question. `find -name 'mail.log*' -mtime -7` picks the
files by name and age, including `var/log/mx2/`. `gzip -cdf` decompresses
`.gz` files to stdout and, thanks to `-f`, passes plain files through, so
all logs become one stream. awk then does a join in memory: the `from` array
remembers the sender domain of every queue ID, the `bounced` array marks the
IDs that bounced, and only in `END`, when every line has been read, are the two
matched. That is why it doesn't matter that a message's from= line can be in
yesterday's file and its bounce in today's. The final `sort -k1,1nr -k2,2`
ranks by count and breaks ties by name before `head` cuts at 5.

## Common mistakes
- `grep status=bounced` alone: those lines name the recipient, not the
  sender. The sender is only on the from= line with the same queue ID.
- Looking up the sender at the moment the bounce is seen: if the files are
  read newest first, the from= line has not been read yet.
- `-mtime 7` or `-mtime +7`: those mean "7 days old" and "more than 7";
  "within the last 7 days" is `-mtime -7`.
- `sort -rn` for ties: it reverses the whole comparison, so tied domains come
  out z to a.

## Learn next
`pflogsumm` builds full postfix reports from these logs, and
`journalctl -u postfix@- --since -7d` does the time filter by message time
instead of file time. For the next step, the same awk join can collect
`dsn=` codes per domain to tell "user unknown" (5.1.1) apart from "blocked as
spam" (5.7.1).
