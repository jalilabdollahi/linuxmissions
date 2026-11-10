# Red Dashboard

## Why it works
`curl -s -o /dev/null -w '%{http_code}\t%{time_total}'` is the standard
health probe: it throws the body away and prints exactly the two numbers
monitoring cares about. `--max-time` turns a hung endpoint into a fast,
explicit failure (`000`, exit code 28) instead of a loop that never ends,
and leaving out `-L` keeps the redirects visible. A redirect on a health URL
usually means the check points at a moved or login-protected page, so the
service may be down while the check looks green.

## Common mistakes
- `curl -L`: a 301 to a working page is reported as 200.
- No timeout: the loop stops at the hung endpoint and the rest are never
  checked. (`--connect-timeout` alone doesn't help here: the connection is
  accepted, the answer never comes.)
- Treating a fast 503 or 404 as "up" because it answered quickly, or a 2 s
  200 as fine because the code is good.

## Learn next
`-w` knows many more timers: `%{time_connect}`, `%{time_starttransfer}`
(time to first byte) and `%{time_namelookup}` split a slow request into
DNS, TCP, and server time. `curl --fail` (or `--fail-with-body`) makes curl
exit non-zero on 4xx/5xx, handy in scripts; `--retry 3 --retry-max-time 10`
adds retries.
