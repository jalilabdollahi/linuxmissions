#!/bin/bash
# Two clocks: the alert bot pasted the kernel's OOM kill of imgproxy in UTC
# (kernel-oom.txt, journalctl --utc -o short-iso), while imgproxy's app.log
# is written in the server's local time with no offset. The server's zone
# comes from the mock timedatectl (bin/). The zone is random per setup and
# always has a half or quarter hour (+03:30, +05:30, +05:45, -03:30, +10:30).
# app.log has exactly one line in each second that matters: the kill second
# in local time (the answer), the UTC clock time read as local, the offset
# applied the wrong way, and the offset rounded to whole hours (decoys).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin etc .lm .lm-state var/log/imgproxy
cp "$M/systemd/timedatectl" bin/
echo img-03 > etc/hostname

ZONES=("Asia/Tehran 210" "Asia/Kolkata 330" "Asia/Kathmandu 345" "America/St_Johns -210" "Australia/Adelaide 630")
read -r ZONE OFFMIN <<< "${ZONES[RANDOM % ${#ZONES[@]}]}"
echo "$ZONE" > etc/timezone
ln -s "/usr/share/zoneinfo/$ZONE" etc/localtime
echo "2026-11-10 09:15:00" > .lm/now
echo "$ZONE" > .lm-state/zone

# Times below are local wall-clock seconds since 2026-11-09 00:00 local.
awk -v seed="$RANDOM$$" -v off=$((OFFMIN * 60)) -v host=img-03 '
function pick(n) { return int(rand() * n) + 1 }
function hex(k,   s, i) { s = ""; for (i = 0; i < k; i++) s = s substr("0123456789abcdef", pick(16), 1); return s }
function wall(t) { return sprintf("2026-11-%02d %02d:%02d:%02d", 9 + int(t / 86400), int(t % 86400 / 3600), int(t % 3600 / 60), t % 60) }
function iso(t) { return sprintf("2026-11-%02dT%02d:%02d:%02d+00:00", 9 + int(t / 86400), int(t % 86400 / 3600), int(t % 3600 / 60), t % 60) }
function line(t, lvl, msg) { printf "%s %-5s %s\n", wall(t), lvl, msg > "var/log/imgproxy/app.log" }
function normal(t,   r, w) {
  r = rand(); w = "[w" pick(8) "]"
  if (r < 0.55) line(t, "INFO", w " GET /img/" hex(12) ".jpg?w=" (160 * pick(8)) " -> 200 (cache hit) " pick(9) "ms")
  else if (r < 0.80) line(t, "INFO", w " resized " hex(12) "." (rand() < 0.7 ? "jpg" : "png") " " (800 + pick(3200)) "x" (600 + pick(2400)) " -> w=" (160 * pick(8)) " in " (20 + pick(300)) "ms")
  else if (r < 0.88) line(t, "INFO", w " GET /img/" hex(12) ".webp?w=" (160 * pick(8)) " -> 304 " pick(3) "ms")
  else if (r < 0.93) line(t, "WARN", w " slow upstream fetch s3://media-prod/" hex(10) " took " (1 + pick(4)) "." pick(9) "s")
  else if (r < 0.97) line(t, "INFO", "[main] stats: rss " (300 + pick(500)) " MiB, " pick(40) " req/s, cache " (70 + pick(29)) "% hit")
  else if (r < 0.985) line(t, "INFO", w " GET /healthz -> 200 0ms")
  else bigtiff(t, w)
}
function bigtiff(t, w) { line(t, "INFO", w " resizing upload/" hex(16) ".tiff " (9000 + pick(15000)) "x" (6000 + pick(10000)) " -> fit 2048 (decoding " pick(5) "." pick(9) " GiB)") }
BEGIN {
  srand(seed)
  start = 6 * 3600; now = 86400 + 9 * 3600 + 15 * 60
  K = 86400 + 1200 + pick(18600)          # the kill, local time, 00:20-05:30 on Nov 10
  U = K - off                              # the same moment as a UTC wall clock
  # Special seconds: the answer and the decoys that stay inside the log.
  spec[K] = "kill"
  cand[1] = U; cand[2] = U - off
  frac = off % 3600; whole = off - frac
  cand[3] = K - frac; cand[4] = K - frac + (off > 0 ? 3600 : -3600)
  for (i = 1; i <= 4; i++) if (cand[i] > start + 60 && cand[i] < now - 60 && cand[i] != K) spec[cand[i]] = "decoy"
  spec[K + 3] = "restart"
  ns = 0; for (s in spec) keys[++ns] = s + 0
  for (i = 2; i <= ns; i++) { v = keys[i]; for (j = i - 1; j >= 1 && keys[j] > v; j--) keys[j + 1] = keys[j]; keys[j + 1] = v }
  si = 1; t = start
  line(t, "INFO", "[main] imgproxy 3.21.0 starting (pid " (900 + pick(4000)) "), 8 workers, max_src_resolution=50MP")
  while (t < now) {
    nt = t + pick(6)
    if (si <= ns && keys[si] <= nt) {
      t = keys[si]; k = spec[t]; si++
      if (k == "kill") bigtiff(t, "[w" pick(8) "]")
      else if (k == "restart") line(t, "INFO", "[main] imgproxy 3.21.0 starting (pid " (20000 + pick(9000)) "), 8 workers, max_src_resolution=50MP")
      else normal(t)
      continue
    }
    t = nt
    if (t < now) normal(t)
  }
  # The kernel side, as pasted by the alert bot (UTC).
  o = "kernel-oom.txt"
  print "# alertbot: kernel messages around the imgproxy restart on img-03" > o
  print "# source: journalctl -k --utc -o short-iso" > o
  pid = 30000 + pick(9000); rss = 3600000 + pick(500000)
  printf "%s %s kernel: TCP: request_sock_TCP: Possible SYN flooding on port 0.0.0.0:443. Sending cookies.\n", iso(U - 7200 - pick(3000)), host > o
  printf "%s %s kernel: audit: type=1400 audit(%d.%03d:%d): apparmor=\"STATUS\" operation=\"profile_replace\" name=\"imgproxy\" pid=%d\n", iso(U - 1800 - pick(1200)), host, 1794200000 + pick(9999), pick(999), 100 + pick(900), 2000 + pick(900) > o
  printf "%s %s kernel: imgproxy invoked oom-killer: gfp_mask=0x140cca(GFP_HIGHUSER_MOVABLE|__GFP_COMP), order=0, oom_score_adj=0\n", iso(U), host > o
  printf "%s %s kernel: CPU: %d PID: %d Comm: imgproxy Not tainted 6.8.0-48-generic #48-Ubuntu\n", iso(U), host, pick(8) - 1, pid > o
  printf "%s %s kernel: Mem-Info:\n", iso(U), host > o
  printf "%s %s kernel: active_anon:%d inactive_anon:%d isolated_anon:0\n", iso(U), host, 900000 + pick(90000), 4000 + pick(900) > o
  printf "%s %s kernel: Tasks state (memory values in pages):\n", iso(U), host > o
  printf "%s %s kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/imgproxy.service,task=imgproxy,pid=%d,uid=998\n", iso(U), host, pid > o
  printf "%s %s kernel: Out of memory: Killed process %d (imgproxy) total-vm:%dkB, anon-rss:%dkB, file-rss:%dkB, shmem-rss:0kB, UID:998 pgtables:%dkB oom_score_adj:0\n", iso(U), host, pid, rss + 900000, rss, 9000 + pick(9000), 7000 + pick(900) > o
  printf "%s %s kernel: oom_reaper: reaped process %d (imgproxy), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB\n", iso(U + 1), host, pid > o
}'
chmod 444 var/log/imgproxy/app.log kernel-oom.txt
cksum < var/log/imgproxy/app.log > .lm-state/app.sum
