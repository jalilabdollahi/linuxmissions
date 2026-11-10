#!/bin/bash
# API gateway export, tab-separated with a header. Every endpoint gets a
# different request count (so the sort order is unambiguous), query strings
# vary per request, 304s log "-" bytes, and latencies span 1 to 4 digits so a
# text comparison of the maximum goes wrong.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

{
  printf 'time\tclient\tmethod\turl\tstatus\tbytes\tlatency_ms\n'
  awk -v seed="$RANDOM$$" '
  BEGIN {
    srand(seed)
    ne = split("/api/users /api/orders /api/products /api/search /api/cart /api/login /api/invoices /health", ep, " ")
    split("?id=%d|?id=%d&expand=orders|?page=%d", qu, "|")
    split("?status=open&page=%d|?id=%d|?since=2026-11-0%d", qo, "|")
    split("?q=red+shoes&page=%d|?q=usb-c%%20cable&sort=price&page=%d|?q=%d", qs, "|")
    # distinct request counts: shuffle a ladder of counts over the endpoints
    for (i = 1; i <= ne; i++) cnt[i] = 40 + i * 30 + int(rand() * 25)
    for (i = ne; i > 1; i--) { j = int(rand() * i) + 1; t = cnt[i]; cnt[i] = cnt[j]; cnt[j] = t }
    for (i = 1; i <= ne; i++) {
      e = ep[i]
      for (k = 1; k <= cnt[i]; k++) {
        r = rand(); url = e
        if (e == "/api/users" && r < 0.7)    url = e sprintf(qu[int(rand() * 3) + 1], 1 + int(rand() * 900))
        if (e == "/api/orders" && r < 0.6)   url = e sprintf(qo[int(rand() * 3) + 1], 1 + int(rand() * 9))
        if (e == "/api/search")              url = e sprintf(qs[int(rand() * 3) + 1], 1 + int(rand() * 9))
        if (e == "/api/products" && r < 0.3) url = e "?category=" (1 + int(rand() * 12))
        if (e == "/api/cart" && r < 0.2)     url = e "?"
        meth = (e == "/api/login" || (e == "/api/cart" && rand() < 0.5)) ? "POST" : "GET"
        st = 200; by = 200 + int(rand() * 40000)
        if (meth == "GET" && e != "/health" && rand() < 0.15) { st = 304; by = "-" }
        else if (rand() < 0.05) { st = (rand() < 0.5) ? 404 : 500; by = 120 + int(rand() * 300) }
        if (e == "/health") by = 15
        lat = 3 + int(rand() * rand() * 400)
        if (rand() < 0.03) lat = 1000 + int(rand() * 4000)
        if (e == "/health") lat = 1 + int(rand() * 9)
        sec = int(rand() * 86400)
        printf "2026-11-09T%02d:%02d:%02dZ\t10.%d.%d.%d\t%s\t%s\t%d\t%s\t%d\n", int(sec / 3600), int(sec / 60) % 60, sec % 60, int(rand() * 4), int(rand() * 255), 1 + int(rand() * 254), meth, url, st, by, lat
      }
    }
  }' | sort
} > gateway.tsv

cksum < gateway.tsv > .lm-state/gateway.sum
