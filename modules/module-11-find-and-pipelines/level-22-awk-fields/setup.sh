#!/bin/bash
# Logfmt To CSV: an application log in logfmt (key=value pairs in any order,
# quoted messages with spaces). dur comes in us, ms or s; some lines have no
# dur, some have look-alike keys (db_dur=, upstream_svc=). Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function secs(ms,   s) { s = sprintf("%.3f", ms / 1000); sub(/0+$/, "", s); sub(/\.$/, "", s); return s "s" }
function shuffle(n,   i, j, t) { for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = kv[i]; kv[i] = kv[j]; kv[j] = t } }
BEGIN {
  srand(seed)
  nsvc = split("api checkout catalog orders search auth", svc, " ")
  split("GET GET GET POST PUT DELETE", meth, " ")
  npath = split("/api/cart /api/orders /api/products /api/search /api/login /api/users/me", path, " ")
  t = 50400
  for (l = 0; l < 2500; l++) {
    t += rand() * 1.4
    ts = sprintf("2026-11-09T%02d:%02d:%06.3fZ", int(t / 3600), int(t / 60) % 60, t % 60)
    s = svc[int(rand() * nsvc) + 1]
    n = 0
    if (rand() < 0.1) {
      # housekeeping lines without a duration
      kv[++n] = "ts=" ts; kv[++n] = "level=" (rand() < 0.5 ? "warn" : "info"); kv[++n] = "svc=" s
      kv[++n] = (rand() < 0.5) ? "msg=\"cache refreshed\" keys=" int(rand() * 900) : "msg=\"connection pool resized\" size=" int(rand() * 40 + 5)
    } else {
      r = rand()
      if (r < 0.15) ms = 501 + int(rand() * 4000)          # slow
      else if (r < 0.18) ms = 500                          # exactly at the limit
      else ms = 1 + int(rand() * 480)
      if (ms < 5 && rand() < 0.7) d = int(ms * 1000 - rand() * 900) "us"
      else if (ms == 500) d = (rand() < 0.5) ? "500ms" : "0.5s"
      else if (ms >= 1000 && rand() < 0.6) d = secs(ms)
      else if (ms > 500 && rand() < 0.15) d = secs(ms)
      else d = ms "ms"
      st = (rand() < 0.9) ? 200 : (rand() < 0.5 ? 404 : 502)
      kv[++n] = "ts=" ts; kv[++n] = "level=" (st == 502 ? "error" : "info"); kv[++n] = "svc=" s
      kv[++n] = "msg=\"request done\""; kv[++n] = "method=" meth[int(rand() * 6) + 1]
      kv[++n] = "path=" path[int(rand() * npath) + 1]; kv[++n] = "status=" st; kv[++n] = "dur=" d
      kv[++n] = sprintf("req=%06x", int(rand() * 16777215))
      if (s == "orders" || s == "checkout") kv[++n] = "db_dur=" int(rand() * ms * 0.9 + 1) "ms"
      if (s == "checkout") kv[++n] = "upstream_svc=payments"
      # a sprinkle of microsecond-level timings that look big
      if (rand() < 0.02) { n = 0; kv[++n] = "ts=" ts; kv[++n] = "level=debug"; kv[++n] = "svc=" s; kv[++n] = "msg=\"cache hit\""; kv[++n] = "dur=" int(600 + rand() * 399) "us" }
    }
    shuffle(n)
    line = kv[1]; for (i = 2; i <= n; i++) line = line " " kv[i]
    print line
  }
}' > app.log

cksum < app.log > .lm-state/log.sum
