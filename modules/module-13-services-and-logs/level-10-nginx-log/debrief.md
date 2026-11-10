# Since the Deploy

## Why it works
The `log_format` line is the key to any nginx log. Here it is the combined format plus
`$request_time $upstream_response_time`. The user agent is quoted and full of spaces,
so the last two fields are easiest to reach from the end: `$NF` is the upstream's time
and `$(NF-1)` the total time nginx spent. The status is `$9` for every well-formed request.

Counting by `$7` would count URLs, and `?id=881234` makes each order its own URL, so
the endpoint that failed most looked tiny. Stripping the query string turns them back into one path.
`/api/v2/checkout` failed on one URL and looked like the top problem when it wasn't.
The cart's storm was at 13:45, before the deploy.

Among the winner's errors, the 504s sit just above 30 s: that is `proxy_read_timeout 30s`.
The backend didn't answer in time, which points at the new code or a slow dependency.

## Common mistakes
- `$(NF-1)` instead of `$NF`: `$request_time` includes the client side and is always a bit higher.
- Treating `-` as 0 or as a string: it means nginx never reached an upstream (the 503s
  from `limit_req`). It is a 5xx, but there is no upstream time.
- Comparing times as numbers after `split`: "14:00:00" as a string compares correctly
  only because the format is fixed-width.

## Next step
Log `$upstream_status` and `$upstream_addr` too. With several backends they show
*which* one failed (and `$upstream_response_time` can hold several comma-separated values
after retries). GoAccess (`goaccess access.log --log-format=COMBINED`) builds these reports
interactively.
