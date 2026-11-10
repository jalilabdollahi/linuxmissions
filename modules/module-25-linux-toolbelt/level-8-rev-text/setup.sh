#!/bin/bash
# 5000 URLs over ~18 registrable domains with random subdomains, schemes, ports,
# paths/queries, some upper-case hosts and trailing dots. A few domains sit under
# two-level suffixes. Counts are skewed; ties are possible on purpose.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

printf '%s\n' co.uk com.au co.jp org.uk > two-level-suffixes.txt

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  nd = split("example.com|bbc.co.uk|shopfast.net|news.org|acme.io|tradecorp.com.au|mangahub.co.jp|openlib.org.uk|gitforge.dev|photo-share.com|streamly.tv|weatherbox.net|cloudnine.io|fastmail.co.uk|bakeoff.com.au|kyoto-travel.co.jp|devtalk.org|cheapflights.com", dom, "|")
  ns = split("www|shop|api|cdn|mail|m|static|login|img|blog|a.b|eu.edge", sb, "|")
  split("/|/index.html|/search?q=linux|/api/v1/items?id=42&sort=asc|/img/logo.png|/a/b/c/d.html|/login|/health", path, "|")
  for (i = 1; i <= nd; i++) w[i] = 1 + int(rand() * rand() * 40)
  for (i = 1; i <= nd; i++) tot += w[i]
  for (n = 0; n < 5000; n++) {
    r = rand() * tot; for (i = 1; i <= nd; i++) { r -= w[i]; if (r <= 0) break }
    if (i > nd) i = nd
    host = dom[i]
    if (rand() < 0.7) host = sb[1 + int(rand() * ns)] "." host
    if (rand() < 0.04) host = toupper(host)
    if (rand() < 0.03) host = host "."
    url = (rand() < 0.8 ? "https://" : "http://") host
    if (rand() < 0.15) url = url ":" (rand() < 0.5 ? "8443" : "8080")
    if (rand() < 0.9) url = url path[1 + int(rand() * 8)]
    print url
  }
}' > urls.txt
cksum < urls.txt > .lm-state/urls.sum
