# Report Pipeline

## Why it works
Two independent mistakes doubled the numbers. After Monday's rotation change
`access.log.1` stays uncompressed, and the script read it by name and again
through a `zcat -f` glob (which passes plain files through), so a whole slice
of the day counted twice. Separately, clients retry failed-looking requests with
the same request ID, so one order can appear as two 200 lines. Listing every file
exactly once and keeping the first line per request ID (`!seen[$3]++`) fixes
both, and an exact match on method, path and status keeps `/checkout/cart` and
failed attempts out.

## Common mistakes
- Fixing the glob only: the report drops, but retried orders are still doubled.
- `sort -u` on the whole line: retries have different timestamps, so they
  survive. Dedupe on the request ID, not the line.
- Testing only on today's logs: a report must also work for another day, where
  rotation put the lines in different files.

## Next step
Compare the report against a second source (the payment dashboard) every day;
`awk 'END { print NR }'` and `sort | uniq -c | sort -rn | head` are the fast
ways to spot a duplicated key.
