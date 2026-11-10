#!/bin/bash
# Wargame 30: leaked key -> bad deploy -> cron every minute -> disk full -> app down.
# A background cron loop (one simulated minute per 2 s) keeps refilling the disk
# until the job is removed from BOTH the user crontab and etc/cron.d.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
pkill -f "$SANDBOX/sim/cronloop.sh" 2>/dev/null
rm -rf bin etc opt var home sim run usr .lm INCIDENT.md postmortem.json
mkdir -p bin sim etc/shop etc/cron.d etc/systemd/system opt/shop/bin home/deploy/.ssh home/ci/.ssh \
         var/cache/shop/audit var/spool/shop var/log/shop var/spool/cron/crontabs .lm
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
UN=$(id -un)
bash "$M/cron/install.sh" "$SANDBOX" --user "$UN" crontab cron-run >/dev/null
echo shop-01 > etc/hostname
ln -s /usr/lib/systemd/system/multi-user.target etc/systemd/system/default.target

PORT=$(python3 -c 'import random,socket
while True:
    p=random.randint(19100,19900); s=socket.socket()
    try: s.bind(("127.0.0.1",p)); s.close(); print(p); break
    except OSError: pass')
echo "PORT=$PORT" > etc/shop/shop.env
echo 40 > etc/shop/disk.limit
echo "$PORT" > .lm/port

# ---- the application
cat > opt/shop/app.py <<'APP'
#!/usr/bin/env python3
import http.server, os, socketserver, sys, threading, time
root = os.environ.get("LM_ROOT", "")
port = int(os.environ["PORT"])
limit = int(open(root + "/etc/shop/disk.limit").read()) * 1024 * 1024
def used():
    t = 0
    for d in ("var/cache/shop", "var/spool/shop", "var/log/shop"):
        for r, _, fs in os.walk(os.path.join(root, d)):
            for f in fs:
                try: t += os.path.getsize(os.path.join(r, f))
                except OSError: pass
    return t
def check():
    u = used()
    if u > limit:
        print("shop: write failed: No space left on device (volume holds %d MB, limit %d MB), exiting" % (u >> 20, limit >> 20), flush=True)
        os._exit(28)
check()
def watch():
    while True:
        time.sleep(1); check()
threading.Thread(target=watch, daemon=True).start()
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        ok = self.path == "/health"
        body = b"ok shop\n" if ok else b"shop\n"
        self.send_response(200 if self.path in ("/health", "/") else 404)
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
class S(socketserver.TCPServer): allow_reuse_address = True
srv = S(("127.0.0.1", port), H)
print("shop: serving on 127.0.0.1:%d" % port, flush=True)
srv.serve_forever()
APP
cat > etc/systemd/system/shop.service <<'U'
[Unit]
Description=Shop storefront

[Service]
Type=exec
EnvironmentFile=/etc/shop/shop.env
ExecStart=/usr/bin/python3 /opt/shop/app.py
Restart=no

[Install]
WantedBy=multi-user.target
U
cat > opt/shop/bin/cache-warm.sh <<'S'
#!/bin/sh
# "cache warmer" added by the 02:3x deploy: one more chunk every run
base=$(cd "$(dirname "$0")/../../.." && pwd)
truncate -s 1M "$base/var/cache/shop/warm-$(date +%H%M).bin"
S
printf '#!/bin/sh\necho "$(date +%%F\\ %%T) heartbeat ok" >> "$(cd "$(dirname "$0")/../../.." && pwd)/var/log/shop/heartbeat.log"\n' > opt/shop/bin/heartbeat.sh
printf '#!/bin/sh\n# nightly order export (kept)\nexit 0\n' > opt/shop/bin/nightly-backup.sh
chmod 755 opt/shop/bin/*.sh

# ---- keys
K=.lm/keys; mkdir -p $K
for k in leaked legit1 legit2 legit3 legit4; do ssh-keygen -q -t ed25519 -N '' -C "$k@x" -f $K/$k; done
ck() { sed "s/ [^ ]*$/ $2/" $K/$1.pub; }
{ ck legit1 alice@laptop; ck leaked deploy-bot@ci-old; ck legit2 bob@laptop; } > home/deploy/.ssh/authorized_keys
{ ck leaked ci-runner@old; ck legit3 ci-runner@new; } > home/ci/.ssh/authorized_keys
cp $K/leaked etc/shop/deploy_key; cp $K/leaked.pub etc/shop/deploy_key.pub; chmod 644 etc/shop/deploy_key
body() { awk '{print $2}' $K/$1.pub; }
cat > etc/shop/deploy.conf <<C
# keys allowed to trigger deploys
key.alice  = ssh-ed25519 $(body legit1) alice@laptop
key.bot    = ssh-ed25519 $(body leaked) deploy-bot@ci-old
key.ci     = ssh-ed25519 $(body legit4) ci-runner@new
C
FP=$(ssh-keygen -lf $K/leaked.pub | awk '{print $2}')
FPL=$(ssh-keygen -lf $K/legit1.pub | awk '{print $2}')
body leaked > .lm/leaked.body
for k in legit1 legit2 legit3 legit4; do body $k; done > .lm/legit.bodies

# ---- timeline: bad deploy, runaway cron since FIRST
DEPLOY_MIN=$((31 + RANDOM % 8))           # 02:31 .. 02:38
FIRST=$((DEPLOY_MIN + 2))
ID="D-$((4000 + RANDOM % 5000))"; OLDID="D-$((3000 + RANDOM % 900))"
printf '2026-11-03 14:20:11 deploy %s started by key %s from 10.0.5.14\n2026-11-03 14:20:19 deploy %s released shop 4.11.2\n' "$OLDID" "$FPL" "$OLDID" > var/cache/shop/audit/deploy-$OLDID.log
printf '2026-11-10 02:%02d:05 deploy %s started by key %s from 203.0.113.9\n2026-11-10 02:%02d:09 deploy %s installed crontab entry for cache-warm.sh\n2026-11-10 02:%02d:12 deploy %s released shop 4.12.0\n' "$DEPLOY_MIN" "$ID" "$FP" "$DEPLOY_MIN" "$ID" "$DEPLOY_MIN" "$ID" > var/cache/shop/audit/deploy-$ID.log
printf "2026-11-10 02:%02d" "$FIRST" > .lm/first_run; echo "$ID" > .lm/deploy_id; echo "$FP" > .lm/fp
sha256sum var/cache/shop/audit/* > .lm/audit.sha

# ---- cron tables: user crontab (via the mock) and a system file
cat > .lm/user.cron <<CR
0 3 * * * $SANDBOX/opt/shop/bin/nightly-backup.sh
* * * * * $SANDBOX/opt/shop/bin/heartbeat.sh
* * * * * $SANDBOX/opt/shop/bin/cache-warm.sh
CR
./bin/crontab .lm/user.cron >/dev/null
echo "* * * * * shop $SANDBOX/opt/shop/bin/cache-warm.sh" > etc/cron.d/warmup

# ---- pre-seed cron.log and the damage up to 03:11
python3 - "$FIRST" "$SANDBOX" "$UN" <<'PY'
import os, random, sys
first, sb, un = int(sys.argv[1]), sys.argv[2], sys.argv[3]
rnd = random.Random()
log = []
for m in range(first, 12 + 60):          # 02:FIRST ... 03:11
    hh, mm = (2, m) if m < 60 else (3, m - 60)
    ts = "Nov 10 %02d:%02d:01" % (hh, mm)
    pid = rnd.randint(1000, 30000)
    if hh == 3 and mm == 0: log.append("%s sandbox CRON[%d]: (%s) CMD (%s/opt/shop/bin/nightly-backup.sh)" % (ts, pid, un, sb))
    log.append("%s sandbox CRON[%d]: (%s) CMD (%s/opt/shop/bin/heartbeat.sh)" % (ts, pid + 1, un, sb))
    log.append("%s sandbox CRON[%d]: (%s) CMD (%s/opt/shop/bin/cache-warm.sh)" % (ts, pid + 2, un, sb))
    log.append("%s sandbox CRON[%d]: (shop) CMD (%s/opt/shop/bin/cache-warm.sh)" % (ts, pid + 3, sb))
    p = os.path.join(sb, "var/cache/shop/warm-%02d%02d.bin" % (hh, mm))
    with open(p, "wb") as f: f.truncate(1 << 20)
open(os.path.join(sb, "var/log/cron.log"), "w").write("\n".join(log) + "\n")
# spool: old orders (deletable), recent orders (keep), logs
def mk(path, size, age_h):
    with open(path, "wb") as f:
        f.write(b'{"order":1}\n'); f.truncate(size)
    t = __import__("time").time() - age_h * 3600
    os.utime(path, (t, t))
mk(os.path.join(sb, "var/spool/shop/orders-2026-11-01.jsonl"), 9 << 20, 24 * 9)
mk(os.path.join(sb, "var/spool/shop/orders-2026-11-04.jsonl"), 9 << 20, 24 * 6)
mk(os.path.join(sb, "var/spool/shop/orders-2026-11-08.jsonl"), 2 << 20, 24 * 2)
mk(os.path.join(sb, "var/spool/shop/orders-2026-11-10.jsonl"), 2 << 20, 3)
open(os.path.join(sb, "var/log/shop/shop.log"), "w").write("2026-11-10 02:10:00 shop 4.11.2 started\n2026-11-10 02:38:12 shop 4.12.0 started\n")
PY
cat > etc/shop/RETENTION.md <<'R'
Retention for the shop volume (limit in disk.limit, MB)
  var/cache/shop/warm-*.bin      cache: anything can go
  var/cache/shop/audit/          audit and deploy evidence: never delete
  var/spool/shop/orders-*.jsonl  keep files modified within the last 3 days; older ones may be deleted
  var/log/shop/                  keep (rotated by the app)
The volume should sit under 50% of the limit after cleanup.
R
cat > INCIDENT.md <<I
PAGE 03:12  shop-01  HTTP 502 from the load balancer. Health endpoint on 127.0.0.1 (port in etc/shop/shop.env).

postmortem.json
  first_bad_cron_run  "YYYY-MM-DD HH:MM"  first run of the runaway job, from the cron log
  key_fingerprint     the SHA256:... fingerprint of the leaked deploy key
  deploy_id           the deploy that used that key (see the deploy audit logs)
  cause_chain         JSON list, root cause first, from this vocabulary:
                      leaked-key, bad-deploy, cron-every-minute, disk-full, app-down,
                      cert-expired, dns-failure, oom-kill, retention-gap
Mock cron: a simulated minute passes every ~2 seconds; the cron log is var/log/cron.log.
I

cat > sim/cronloop.sh <<'LOOP'
#!/bin/bash
# the simulated cron daemon: one simulated minute every 2 seconds
SB="$1"; T="$2"; export LM_CRON_USER="$3"
while :; do
  "$SB/bin/cron-run" --root "$SB" --at "$T" --no-periodic -q --log "$SB/var/log/cron.log" >/dev/null 2>&1
  sleep 2
  T=$(date -d "$T + 1 minute" '+%Y-%m-%d %H:%M')
done
LOOP
chmod 755 sim/cronloop.sh

# ---- start: app dies on a full disk, cron keeps running
./bin/systemctl daemon-reload
./bin/systemctl start shop >/dev/null 2>&1
sleep 1
setsid bash "$SANDBOX/sim/cronloop.sh" "$SANDBOX" "2026-11-10 03:12" "$UN" >/dev/null 2>&1 &
exit 0
