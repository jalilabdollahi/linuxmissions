# Renewed, Not Fixed

## Why it works
You checked every certificate the way a browser does:
- **Dates:** `-checkend 0` (or `-dates`) caught the old certificate that was
  deployed again instead of the renewed one.
- **Chain:** the server must send its certificate *and* the intermediate.
  `openssl verify -CAfile root -untrusted fullchain.pem` uses exactly that,
  so a file holding only the leaf fails with error 20. (Some browsers hide
  this by fetching or caching intermediates, which is why "works on my
  machine" is common, but curl, Java and mobile apps fail.)
- **Name:** since RFC 2818 / the CA/Browser Forum rules, clients use the
  subjectAltName list and ignore the CN when a SAN is present. One cert had
  the right CN but other names in its SAN; the wildcard cert had CN
  `*.corp.example`, which doesn't equal the hostname, yet its SAN covers it.

## Common mistakes
- Comparing the CN with the hostname: wrong for both the NAME and the
  wildcard case.
- Verifying with the intermediate in `-CAfile`: that trusts it, so the
  missing intermediate on the server is never noticed.
- Expecting `*.corp.example` to match `a.b.corp.example`; a wildcard covers
  one label only.

## Learn next
Against a live server: `openssl s_client -connect host:443 -servername host
-showcerts </dev/null` shows the chain it really sends, and
`-verify_hostname host -CAfile root.pem` checks name and chain together.
`curl --cacert root.pem https://host/` fails with exit 60 on any of these
problems.
