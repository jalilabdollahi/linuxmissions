#!/bin/bash
# Needle in huge.log: 200,000 lines of an orders-api log from one day. The
# deploy job writes "deploy finished: release ..." markers, plus a dry-run
# marker "deploy finished (dry-run): ..." between real deploy 1 and 2. Worker
# panics are scattered over the day: one before deploy 1, one after it, one
# after the dry run, and then the one the player wants: the first after the
# second REAL deploy. The line two above each panic is the worker's ERROR line
# with the job's trace id; the line right above is an unrelated line (with
# its own trace id half of the time). After every deploy the service dumps
# its config, including panic_on_fail=false, so a plain /panic search stops
# there first. Positions, ids and messages are random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" -v total=200000 '
function hex(   a, b) { a = int(rand() * 4294967296); b = int(rand() * 4294967296); return sprintf("%08x%08x", a, b) }
function pick(n) { return int(rand() * n) + 1 }
function stamp(   s, ms) {
  s = int(n * 0.431) + 7; ms = int(n * 431) % 1000
  return sprintf("2026-11-10T%02d:%02d:%02d.%03dZ", int(s / 3600) % 24, int(s / 60) % 60, s % 60, ms)
}
function out(lvl, comp, msg) { n++; printf "%s %-5s [%s] %s\n", stamp(), lvl, comp, msg }
function normal(   r, ms) {
  r = rand(); ms = 3 + int(rand() * 60)
  if (r < 0.52) out("INFO", "http", "trace=" hex() " GET " path[pick(np)] pick(99999) " 200 " ms "ms")
  else if (r < 0.60) out("INFO", "http", "trace=" hex() " POST /api/v1/orders 201 " (ms + 20) "ms")
  else if (r < 0.64) out("WARN", "http", "trace=" hex() " POST /api/v1/checkout 200 " (900 + int(rand() * 2400)) "ms (slow)")
  else if (r < 0.67) out("INFO", "http", "trace=" hex() " GET " path[pick(np)] pick(99999) " 404 " ms "ms")
  else if (r < 0.82) out("INFO", "worker", "trace=" hex() " job " (40000 + pick(59999)) " (" jobs[pick(nj)] ") done in " (ms * 7) "ms")
  else if (r < 0.92) out("DEBUG", "db", "pool: open=" (8 + pick(24)) " idle=" pick(8) " wait=0")
  else if (r < 0.97) out("INFO", "cache", "hit ratio 0." (80 + pick(19)) " over last 60s")
  else out("INFO", "scheduler", "tick: " pick(9) " jobs queued, " pick(3) " delayed")
}
function deploy(rel, dry,   k) {
  out("INFO", "deploy", "deploy started: release " rel (dry ? " (dry-run)" : "") " by " who[pick(nw)])
  for (k = 0; k < 6 + pick(20); k++) normal()
  if (dry) { out("INFO", "deploy", "deploy finished (dry-run): release " rel ", " pick(400) " files would change"); return }
  out("INFO", "deploy", "deploy finished: release " rel " (" (300 + pick(200)) " files, " (20 + pick(70)) "s)")
  normal()
  out("INFO", "main", "orders-api " rel " starting, pid " (2000 + pick(30000)))
  out("INFO", "main", "config: workers=" (4 + pick(12)) " queue=orders panic_on_fail=false retry=3")
  out("INFO", "main", "listening on :8080")
}
function panic(   k) {
  out("ERROR", "worker", "trace=" hex() " job " (40000 + pick(59999)) " (" jobs[pick(nj)] ") crashed, recovering stack")
  if (rand() < 0.5) out("INFO", "http", "trace=" hex() " GET " path[pick(np)] pick(99999) " 200 " (3 + pick(40)) "ms")
  else out("DEBUG", "db", "pool: open=" (8 + pick(24)) " idle=0 wait=" pick(4))
  out("ERROR", "worker", "panic: " why[pick(nwhy)])
  out("ERROR", "worker", "goroutine " (300 + pick(9000)) " [running]:")
  out("ERROR", "worker", "orders-api/internal/" frames[pick(nf)])
  out("ERROR", "worker", "orders-api/internal/worker.(*Pool).run(0xc000" sprintf("%06x", pick(16777215)) ")")
  out("WARN", "worker", "worker " pick(16) " restarted by supervisor")
}
BEGIN {
  srand(seed)
  np = split("/api/v1/orders/ /api/v1/customers/ /api/v1/invoices/ /api/v1/products/", path, " ")
  nj = split("invoice.render invoice.email stock.sync report.daily payment.capture", jobs, " ")
  nw = split("ci-bot ci-bot ci-bot m.rahimi s.okafor", who, " ")
  nwhy = split("runtime error: invalid memory address or nil pointer dereference|runtime error: index out of range [3] with length 3|assignment to entry in nil map|send on closed channel|runtime error: slice bounds out of range [:12] with capacity 8", why, "|")
  nf = split("render.(*Invoice).Totals(...)|stock.(*Syncer).apply(0x0)|payment.Capture(0xc00041e2a0)|report.(*Daily).Rows(0x0, 0x1f)", frames, "|")
  # Where things happen (line numbers): real deploys r1 < r2 < r3 with a
  # dry run d between r1 and r2; panics p0 < r1 < p1 < d < pd < r2 < pa < pz < r3.
  r1 = 25000 + pick(15000); d = 60000 + pick(20000); r2 = 110000 + pick(20000); r3 = 160000 + pick(15000)
  ev[2000 + pick(18000)] = "panic"
  ev[r1] = "r1"
  ev[r1 + 2000 + pick(20000)] = "panic"
  ev[d] = "dry"
  ev[d + 1500 + pick(15000)] = "panic"
  ev[r2] = "r2"
  pa = r2 + 900 + pick(25000); ev[pa] = "panic"
  ev[pa + 3000 + pick(8000)] = "panic"
  ev[r3] = "r3"
  ev[r3 + 1000 + pick(15000)] = "panic"
  rel = "2026.11.10-"
  while (n < total) {
    e = ev[n + 1]
    if (e == "panic") panic()
    else if (e == "r1") deploy(rel "1", 0)
    else if (e == "dry") deploy(rel "2", 1)
    else if (e == "r2") deploy(rel "2", 0)
    else if (e == "r3") deploy(rel "3", 0)
    else normal()
  }
}' > huge.log
chmod 444 huge.log
cksum < huge.log > .lm-state/huge.sum

cat > NOTE.txt <<'EOF'
From: s.okafor
Re: worker panics on orders-api today

The panic we care about is the first worker panic after the SECOND deploy of
today that really went out. Dry runs don't count, they change nothing.
huge.log has the whole day. The line two lines above a panic is the worker's
error line for the crashed job; I need its trace id to pull the request from
tracing.

Please put just the id (the 16 hex digits after trace=) into trace.txt.
EOF
