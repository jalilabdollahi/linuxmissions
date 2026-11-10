#!/bin/bash
# Who Killed the Worker: ~3000 log lines. 15 FATAL blocks; three of them are
# two or three FATAL lines in a row. The line before each block carries
# req=<id>; some lines (also before a FATAL) carry parent_req=<id> as well,
# which `grep -o 'req=...'` picks up by accident.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM" '
function id(   s, i) { s = ""; for (i = 0; i < 8; i++) s = s substr("0123456789abcdef", 1 + int(rand() * 16), 1); return s }
function ts() { t += 1 + int(rand() * 25); return sprintf("2026-11-10T%02d:%02d:%02dZ", t / 3600, (t / 60) % 60, t % 60) }
function reqline(lvl, msg,   p) {
  p = (rand() < 0.3) ? " parent_req=" id() : ""
  printf "%s %s worker=w%d req=%s%s job=%s %s\n", ts(), lvl, 1 + int(rand() * 4), last = id(), p, job[1 + int(rand() * 4)], msg
}
BEGIN {
  srand(seed); t = 3600
  split("resize thumbnail watermark convert", job, " ")
  split("2 0 0 3 0 0 0 0 2 0 0 0 0 0 0", nf, " ")   # 0 = a single FATAL
  for (b = 1; b <= 15; b++) gap[b] = 120 + int(rand() * 140)
  for (b = 1; b <= 15; b++) {
    for (i = 0; i < gap[b]; i++) {
      r = rand()
      if (r < 0.55)      reqline("INFO", "msg=\"done in " int(rand() * 900) "ms\"")
      else if (r < 0.7)  reqline("WARN", "msg=\"slow source image, " int(rand() * 40) " MB\"")
      else if (r < 0.8)  reqline("ERROR", "msg=\"upstream 503, will retry\"")
      else if (r < 0.9)  printf "%s INFO worker=w%d msg=\"heartbeat ok\" queue=%d\n", ts(), 1 + int(rand() * 4), int(rand() * 300)
      else               printf "%s DEBUG worker=w%d msg=\"gc pause %dms\"\n", ts(), 1 + int(rand() * 4), int(rand() * 80)
    }
    reqline((rand() < 0.5 ? "INFO" : "ERROR"), "msg=\"decoding " int(rand() * 9000) "x" int(rand() * 9000) " image\"")
    print last > ".lm-state/fatal-reqs"
    n = (nf[b] > 0) ? nf[b] : 1
    for (k = 0; k < n; k++)
      printf "%s FATAL worker=w%d msg=\"%s\"\n", ts(), 1 + int(rand() * 4), (k == 0 ? "runtime: out of memory, killed" : "supervisor: restart failed, worker still down")
  }
  for (i = 0; i < 80; i++) reqline("INFO", "msg=\"done in " int(rand() * 900) "ms\"")
}' > worker.log
cksum < worker.log > .lm-state/log.sum
