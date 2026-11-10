# Not Through the Proxy

## Why it works
There is no standard for proxy variables, only conventions, and every tool
reads them a little differently. curl reads `http_proxy` only in lower
case (CGI programs get an attacker-controlled `HTTP_PROXY` from the `Proxy:`
request header, the "httpoxy" problem), `https_proxy` in either case, and
`no_proxy` before `NO_PROXY`. So the old file's correct `NO_PROXY` line was
never read, and its `no_proxy=*.internal` didn't match anything: curl,
wget and Python take a leading dot (or nothing) as "this domain and
everything below it", and `*` only on its own. Setting all six variables
with identical values (by copying with `$http_proxy`) makes every tool agree.

## Common mistakes
- Writing `*.internal` because it looks like a glob. Use `.internal`.
- Forgetting `localhost` and `127.0.0.1`: curl proxies them too unless they
  are listed.
- Fixing only one spelling: Python, Go and many CLIs read the upper-case
  names; curl and wget read the lower-case ones.
- Not exporting: a variable set without `export` is invisible to the curl
  process.

## Learn next
`curl --noproxy '*' URL` bypasses the proxy for one call, `curl -x
http://proxy:3128 URL` sets one explicitly. CIDR ranges in `no_proxy`
(`10.0.0.0/8`) work in curl ≥ 7.86 and Go, but not in wget. For HTTPS,
clients send `CONNECT host:443` to the proxy and tunnel TLS through it.
