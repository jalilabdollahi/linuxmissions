#!/bin/bash
# One day of combined-format access log. Traffic follows the day, errors
# come in two waves, a 2-4 hour maintenance window at night has no lines at
# all, and a few junk requests ("-" or raw TLS bytes) have no method and path,
# which shifts every whitespace field after them (status is not $9 there).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  q0 = 1 + int(rand() * 2); q1 = q0 + 1 + int(rand() * 3)      # quiet hours q0..q1
  w1 = 9 + int(rand() * 4); w2 = 15 + int(rand() * 5)            # error waves
  np = split("/ /cart /checkout /product/4411 /product/872 /search?q=lamp /static/app.js /static/logo.png /api/stock /login /account", path, " ")
  nu = split("Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0|Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15|Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36|curl/8.5.0|Googlebot/2.1 (+http://www.google.com/bot.html)", ua, "|")
  for (h = 0; h < 24; h++) {
    if (h >= q0 && h <= q1) continue
    n = 10 + int(rand() * 20) + ((h >= 8 && h <= 22) ? 60 + int(rand() * 60) : 0)
    for (i = 0; i < n; i++) sec[++m] = h * 3600 + int(rand() * 3600)
  }
  # sort the seconds (insertion sort is fine for a few thousand lines)
  for (i = 2; i <= m; i++) { v = sec[i]; j = i - 1; while (j > 0 && sec[j] > v) { sec[j + 1] = sec[j]; j-- } sec[j + 1] = v }
  for (i = 1; i <= m; i++) {
    s = sec[i]; h = int(s / 3600)
    ts = sprintf("[10/Nov/2026:%02d:%02d:%02d +0000]", h, int(s / 60) % 60, s % 60)
    ip = sprintf("%d.%d.%d.%d", 23 + int(rand() * 180), int(rand() * 256), int(rand() * 256), 1 + int(rand() * 254))
    r = rand()
    if (r < 0.01) { printf "%s - - %s \"-\" 408 0 \"-\" \"-\"\n", ip, ts; continue }
    if (r < 0.02) { printf "%s - - %s \"\\x16\\x03\\x01\\x00\\xF1\\x01\\x00\" 400 157 \"-\" \"-\"\n", ip, ts; continue }
    p = path[int(rand() * np) + 1]
    meth = (p == "/checkout" || p == "/login") && rand() < 0.5 ? "POST" : "GET"
    e = (h == w1 || h == w2) ? 0.35 : 0.03
    r = rand()
    if (r < e * 0.6)      st = (rand() < 0.7) ? 502 : 503
    else if (r < e)       st = 500
    else if (r < e + 0.06) st = (rand() < 0.8) ? 404 : 403
    else if (r < e + 0.16) st = (rand() < 0.7) ? 304 : 301
    else                  st = (meth == "POST") ? 201 : 200
    by = (st == 304) ? 0 : 150 + int(rand() * 30000)
    printf "%s - - %s \"%s %s HTTP/1.1\" %d %d \"https://shop.example.com/\" \"%s\"\n", ip, ts, meth, p, st, by, ua[int(rand() * nu) + 1]
  }
}' > access.log

cksum < access.log > .lm-state/access.sum
