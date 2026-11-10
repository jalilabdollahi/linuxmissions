# Pipeline Master

## Why it works
Each stage does one job and passes its output on: filter, extract, group, count,
rank. The filter is the important part. `grep POST` also matches
`GET /docs/POST-requests`, which put two crawlers that never sent a POST at the top
of the list. Matching `"POST ` (quote, method, space), or comparing awk's field 6,
only matches the method itself.

## Common mistakes
- Filtering on a word that can appear anywhere in the line (URL, user agent, referer).
- Skipping the first `sort`, so `uniq -c` counts the same IP many times.
- Building the whole pipeline at once: when the result looks wrong, you cannot see
  which stage broke. Add stages one by one and check with `| head`.

## Learn next
`tee` saves a copy of the stream mid-pipeline:
`grep '"POST ' access.log | tee posts.log | awk '{print $1}' | ...`.
`awk '$6 == "\"POST" {n[$1]++} END {for (ip in n) print n[ip], ip}' access.log | sort -rn`
does the filter and the count in one awk program.
