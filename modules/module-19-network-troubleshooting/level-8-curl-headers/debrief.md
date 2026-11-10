# Stale Status Page

## Why it works
`curl -L` follows redirects like a browser, and `-w '%{url_effective}
%{num_redirects}'` reports where it ended and how it got there. With `-L`
plus `-D -` or `-I`, curl prints one header block per hop. The first redirect
had a `Cache-Control: max-age=3600` of its own, so grepping all of them gives
several answers; only the last block belongs to the page.

The real twist was HEAD vs GET. `curl -I` sends HEAD, and this server
(a misconfigured cache rule) answers HEAD with the previous build's ETag and a
much longer max-age, while browsers' GET requests get the new build. The
uptime check was looking at the wrong thing. Customers still see the old page
because the old version was cached with its long max-age, so their browsers
don't ask again until it expires.

## Common mistakes
- Using `curl -I` to "see what users see": it is a different request method.
- Reading the first Cache-Control in `curl -sIL` output: that one belongs to a redirect.
- `curl -v` writes headers to stderr: add `2>&1` before piping it to grep.

## Learn next
curl 7.84+ can print single headers directly:
`curl -s -L -o /dev/null -w '%header{etag} %header{cache-control}\n' URL`.
`curl -H 'If-None-Match: "ETAG"' -I URL` shows a conditional request:
a 304 means the client's copy is still current.
