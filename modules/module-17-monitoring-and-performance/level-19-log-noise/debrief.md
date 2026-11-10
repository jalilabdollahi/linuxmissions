# Turn Down the Noise

## Why it works
Counting identical lines tells you nothing when every line contains a
timestamp, an ID and a counter. Masking those parts with `sed -E` turns each
line into its template, and `sort | uniq -c | sort -rn` ranks the templates by
volume: three of them account for most of the file. `grep -vEf` then removes
every line that matches any pattern in the file. The patterns have to be as
narrow as the template: keeping the level (`DEBUG`, `INFO`) and the fixed words
separates the noisy `DEBUG ... /v1/errors/report ... status=200` from the
`ERROR` line with the same URL, which must stay.

## Common mistakes
- A pattern like `error` or `/errors/report` that also drops real ERROR lines.
- Dropping a whole level (`DEBUG`): other DEBUG lines are not part of the noise.
- A blank line in the patterns file: an empty regex matches every line.
- Forgetting to escape `?` or `.` in an extended regex.

## Next step
`grep -c` before and after is a quick safety check; `logrotate`, a log level
change in the application and `rsyslog` filters fix the problem at the source.
`grep -F -f` treats the patterns as fixed strings when you need no regex.
