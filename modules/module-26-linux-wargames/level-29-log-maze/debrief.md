## What you did

You followed one failure across five services by normalising everything first: UTC ISO, UTC with a bracketed date, `+0330` local time, `+01:00` local seconds and epoch milliseconds all became one clock, and the five names for the request ID (`request_id`, `X-Request-ID`, `trace`, `req`, `rid`) became one key. With a common timeline the cause is visible: inventory's connection-pool error is the earliest ERROR on any failing request, and checkout's timeout and the gateway's 502 are just its echoes. The earlier ERRORs in payments and notifier belonged to requests that eventually succeeded, and the 40-line stack trace was one event.

## Common mistakes

- Comparing raw time strings across files: `18:01` (local) sorts after `14:31` (UTC) although it is the same moment.
- Picking the first ERROR in the combined output: unrelated or recovered errors come earlier.
- Counting every stack-trace line as a log event.

## Next

`journalctl -o json | jq`, `lnav` and `awk` with `strptime` (gawk) merge logs of different formats; structured logging with a propagated trace ID (W3C `traceparent`) removes most of this work.
