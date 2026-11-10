#!/bin/bash
# One timeline, four clocks. web-01 (Asia/Tehran, +03:30) had an API outage
# between 03:00 and 03:15 local time on Nov 10. The evidence:
#   export/journal.json       journalctl -u api -u nginx -o json (µs epoch)
#   var/log/syslog            rsyslog, "Nov 10 03:04:05", no year, no zone;
#                             it also holds a copy of every journal line
#   var/log/nginx/access.log  combined format, [10/Nov/2026:03:04:05 +0330]
#   var/log/api/app.log       ISO 8601 with milliseconds and +03:30
# The incident story (pool exhaustion, worker timeouts, OOM kill of a
# worker, restart) is fixed; the times, PIDs, clients and counts are random,
# and several events of different sources fall in the same second.
# The mock timedatectl/journalctl are in bin/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin etc .lm export var/log/nginx var/log/api
cp "$M/systemd/timedatectl" "$M/systemd/journalctl" bin/
echo web-01 > etc/hostname
echo Asia/Tehran > etc/timezone
ln -s /usr/share/zoneinfo/Asia/Tehran etc/localtime
echo "2026-11-10 03:40:00" > .lm/now

python3 - "$RANDOM$$" <<'PY'
import json, random, sys, uuid
from datetime import datetime, timedelta, timezone

R = random.Random(int(sys.argv[1]))
TZ = timezone(timedelta(hours=3, minutes=30))
HOST = "web-01"
BOOT = uuid.UUID(int=R.getrandbits(128)).hex
T0 = datetime(2026, 11, 10, 2, 45, 0, tzinfo=TZ).timestamp()   # logs start
W0 = datetime(2026, 11, 10, 3, 0, 0, tzinfo=TZ).timestamp()    # incident window
END = datetime(2026, 11, 10, 3, 35, 0, tzinfo=TZ).timestamp()  # logs end

journal, syslog_extra, nginx, app = [], [], [], []
api_pid = R.randint(2100, 2900)
ngx_master = R.randint(880, 990)
ngx_worker = ngx_master + 1

def J(t, ident, pid, prio, msg, unit, uid="0"):
    journal.append((t, ident, pid, prio, msg, unit, uid))

def S(t, prog, msg):
    syslog_extra.append((t, prog, msg))

def A(t, level, msg):
    app.append((t, level, msg))

CLIENTS = ["10.0.4.%d" % R.randint(2, 250) for _ in range(9)]
PATHS = ["/api/v1/orders", "/api/v1/orders?page=2", "/api/v1/cart", "/api/v1/checkout",
         "/api/v1/products?q=lamp", "/api/v1/customers/me", "/healthz"]
UAS = ['"Mozilla/5.0 (X11; Linux x86_64) Firefox/131.0"', '"okhttp/4.12.0"', '"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X)"', '"kube-probe/1.30"']

def N(t, status, path=None, method=None):
    path = path or R.choice(PATHS)
    method = method or ("POST" if path in ("/api/v1/checkout", "/api/v1/cart") and R.random() < 0.7 else "GET")
    size = R.randint(150, 9000) if status < 500 else (157 if status == 502 else 167)
    nginx.append((t, R.choice(CLIENTS), method, path, status, size, R.choice(UAS)))

# Background: steady traffic, info lines, cron and kernel noise all the way through.
t = T0
while t < END:
    t += R.uniform(0.3, 2.5)
    N(t, R.choice([200, 200, 200, 200, 304, 201, 404]))
t = T0
while t < END:
    t += R.uniform(8, 40)
    A(t, "INFO", R.choice(["request served in %dms" % R.randint(8, 90), "cache refresh: %d keys" % R.randint(100, 900),
                          "db pool usage %d/32" % R.randint(4, 14)]))
for m in range(45, 95, 5):   # every 5 minutes from 02:45
    ts = datetime(2026, 11, 10, 2, 0, 0, tzinfo=TZ).timestamp() + m * 60 + R.uniform(0.01, 0.9)
    if ts < END:
        S(ts, "CRON[%d]" % R.randint(30000, 39999), "(root) CMD (command -v debian-sa1 > /dev/null && debian-sa1 1 1)")
S(T0 + R.uniform(100, 500), "systemd-timesyncd[612]", "Contacted time server 185.125.190.57:123 (ntp.ubuntu.com).")
S(T0 + R.uniform(1200, 1500), "sshd[%d]" % R.randint(40000, 49999), "Accepted publickey for deploy from 10.0.9.4 port 51122 ssh2: ED25519 SHA256:3vX9kq")
S(END - R.uniform(60, 400), "systemd[1]", "Starting sysstat-collect.service - system activity accounting tool...")
for i in range(R.randint(8, 14)):
    S(R.uniform(T0, END), "kernel", "[%d.%06d] [UFW BLOCK] IN=eth0 OUT= MAC=52:54:00:3a:1f:0c SRC=%d.%d.%d.%d DST=10.0.4.1 LEN=44 TOS=0x00 PREC=0x00 TTL=%d ID=%d PROTO=TCP SPT=%d DPT=%d WINDOW=1024 RES=0x00 SYN URGP=0"
      % (R.randint(80000, 90000), R.randint(0, 999999), R.randint(1, 223), R.randint(0, 255), R.randint(0, 255), R.randint(1, 254),
         R.randint(40, 250), R.randint(1, 65000), R.randint(1024, 65000), R.choice([22, 23, 3389, 5432, 6379, 8080])))

# The incident, inside the window.
a = W0 + R.uniform(20, 90)                 # pool starts to fill
A(a, "WARN", "db pool usage 28/32, slow query on orders_by_customer (%.1fs)" % R.uniform(2, 6))
J(a + R.uniform(5, 30), "api", api_pid, 4, "slow request GET /api/v1/orders took %dms" % R.randint(4000, 9000), "api.service", "998")
b = a + R.uniform(60, 120)                 # exhausted
A(b, "ERROR", "db pool exhausted (32/32 in use), %d requests queued" % R.randint(20, 60))
J(b + R.uniform(0.01, 0.3), "api", api_pid, 3, "QueuePool limit of size 32 overflow 0 reached, connection timed out, timeout 30.00", "api.service", "998")
# 502s and 504s while workers hang
first502 = b + R.uniform(10, 40)
t = first502
for i in range(R.randint(14, 22)):
    N(t, 502 if R.random() < 0.8 else 504)
    if R.random() < 0.3:
        J(t + R.uniform(0, 0.4), "nginx", ngx_master, 3,
          '%s [error] %d#%d: *%d upstream prematurely closed connection while reading response header from upstream, client: %s, server: api.example.net, request: "GET /api/v1/orders HTTP/1.1", upstream: "http://127.0.0.1:8000/api/v1/orders"'
          % (datetime.fromtimestamp(t, TZ).strftime("%Y/%m/%d %H:%M:%S"), ngx_worker, ngx_worker, R.randint(40000, 90000), R.choice(CLIENTS)), "nginx.service", "33")
    t += R.uniform(1, 9)
k = t + R.uniform(5, 20)                   # a worker is OOM-killed, the unit restarts
k = int(k) + 0.25                          # several sources in this same second
J(k, "api", api_pid, 2, "[CRITICAL] WORKER TIMEOUT (pid:%d)" % (api_pid + 3), "api.service", "998")
N(k + 0.1, 502, "/api/v1/checkout", "POST")
A(k + 0.4, "ERROR", "worker %d killed by master after 30s timeout" % (api_pid + 3))
S(k + 0.3, "kernel", "[%d.%06d] Out of memory: Killed process %d (gunicorn) total-vm:1834220kB, anon-rss:1203112kB, file-rss:2104kB, shmem-rss:0kB, UID:998 pgtables:2640kB oom_score_adj:0" % (R.randint(80000, 90000), R.randint(0, 999999), api_pid + 3))
r = k + R.uniform(2, 6)
J(r, "systemd", 1, 5, "api.service: Main process exited, code=killed, status=9/KILL", "api.service")
J(r + 0.001, "systemd", 1, 4, "api.service: Failed with result 'signal'.", "api.service")
r2 = r + 5.0 + R.uniform(0, 0.3)
J(r2, "systemd", 1, 6, "api.service: Scheduled restart job, restart counter is at 1.", "api.service")
J(r2 + 0.002, "systemd", 1, 6, "Stopped api.service - Orders API (gunicorn).", "api.service")
J(r2 + 0.004, "systemd", 1, 6, "Starting api.service - Orders API (gunicorn)...", "api.service")
new_pid = api_pid + R.randint(400, 900)
J(r2 + 1.2, "api", new_pid, 6, "Starting gunicorn 22.0.0", "api.service", "998")
J(r2 + 1.3, "api", new_pid, 6, "Listening at: http://127.0.0.1:8000 (%d)" % new_pid, "api.service", "998")
J(r2 + 1.3, "systemd", 1, 6, "Started api.service - Orders API (gunicorn).", "api.service")
A(r2 + 1.6, "INFO", "orders-api 4.8.2 ready, db pool size 32")
for i in range(R.randint(3, 6)):            # stragglers while it warms up
    N(r2 + R.uniform(0.1, 1.2), 502)
A(r2 + R.uniform(30, 90), "WARN", "db pool usage 25/32 after restart, slow query on orders_by_customer (%.1fs)" % R.uniform(1, 3))
fix = W0 + 14 * 60 + R.uniform(0, 40)
J(fix, "nginx", ngx_master, 5, "signal process started", "nginx.service", "0")
J(fix - 0.2, "systemd", 1, 6, "Reloading nginx.service - A high performance web server and a reverse proxy server...", "nginx.service")
J(fix + 0.3, "systemd", 1, 6, "Reloaded nginx.service - A high performance web server and a reverse proxy server.", "nginx.service")
A(fix + R.uniform(1, 5), "WARN", "rate limit for /api/v1/orders lowered to 50 r/s by ops")
# Events right at the window edges (just outside and just inside).
A(W0 - R.uniform(0.01, 0.9), "WARN", "db pool usage 22/32")
A(W0 + 15 * 60 + R.uniform(0.01, 3), "ERROR", "db pool exhausted (32/32 in use), %d requests queued" % R.randint(5, 9))
N(W0 + 15 * 60 - 1 + R.uniform(0.01, 0.9), 503, "/api/v1/orders")
J(W0 - 30 - R.uniform(0, 30), "api", api_pid, 4, "slow request GET /api/v1/cart took %dms" % R.randint(2000, 3000), "api.service", "998")

# ---- write the files
def epoch_us(t):
    return int(round(t * 1e6))

journal.sort(key=lambda e: e[0])
seq = R.randint(0x100000, 0x900000)
with open("export/journal.json", "w") as f:
    for i, (t, ident, pid, prio, msg, unit, uid) in enumerate(journal):
        e = {"__CURSOR": "s=%s;i=%x;b=%s" % (BOOT[:32], seq + i, BOOT),
             "__REALTIME_TIMESTAMP": str(epoch_us(t)),
             "__MONOTONIC_TIMESTAMP": str(epoch_us(t - T0 + 86000)),
             "_BOOT_ID": BOOT, "PRIORITY": str(prio), "SYSLOG_FACILITY": "3",
             "SYSLOG_IDENTIFIER": ident, "_PID": str(pid), "_UID": uid, "_HOSTNAME": HOST,
             "_TRANSPORT": "journal" if ident == "systemd" else "stdout", "MESSAGE": msg}
        if ident == "systemd":
            e["UNIT"] = unit
            e["_SYSTEMD_UNIT"] = "init.scope"
        else:
            e["_SYSTEMD_UNIT"] = unit
            e["_COMM"] = "gunicorn" if ident == "api" else "nginx"
        f.write(json.dumps(e) + "\n")

# rsyslog: every journal entry (same second) plus the lines that are only in syslog.
lines = [(t, "%s[%d]" % (ident, pid), msg) for (t, ident, pid, prio, msg, unit, uid) in journal] + syslog_extra
lines.sort(key=lambda x: x[0])
with open("var/log/syslog", "w") as f:
    for t, prog, msg in lines:
        d = datetime.fromtimestamp(int(t), TZ)
        f.write("%s %2d %s %s %s: %s\n" % (d.strftime("%b"), d.day, d.strftime("%H:%M:%S"), HOST, prog, msg))

nginx.sort(key=lambda x: x[0])
with open("var/log/nginx/access.log", "w") as f:
    for t, ip, method, path, status, size, ua in nginx:
        d = datetime.fromtimestamp(int(t), TZ)
        ref = '"https://shop.example.net/"' if R.random() < 0.4 else '"-"'
        f.write('%s - - [%s] "%s %s HTTP/1.1" %d %d %s %s\n' % (ip, d.strftime("%d/%b/%Y:%H:%M:%S %z"), method, path, status, size, ref, ua))

app.sort(key=lambda x: x[0])
with open("var/log/api/app.log", "w") as f:
    for t, level, msg in app:
        d = datetime.fromtimestamp(t, TZ)
        f.write("%s.%03d+03:30 %s %s\n" % (d.strftime("%Y-%m-%dT%H:%M:%S"), d.microsecond // 1000, level, msg))
PY

chmod 444 export/journal.json var/log/syslog var/log/nginx/access.log var/log/api/app.log
mkdir -p .lm-state
cat export/journal.json var/log/syslog var/log/nginx/access.log var/log/api/app.log | cksum > .lm-state/sources.sum

cat > TIMELINE-SPEC.txt <<'EOF'
Incident timeline for the postmortem (INC-7731, web-01)
=======================================================

Window: Nov 10, 03:00:00 to 03:14:59 server local time (both ends included).
File:   timeline.txt, one event per line:

    TIME SOURCE MESSAGE

TIME     UTC as YYYY-MM-DDTHH:MM:SSZ. Cut off fractions of a second, don't round.
SOURCE   journal, syslog, nginx or app.
MESSAGE  depends on the source:
  journal  export/journal.json (journalctl -o json): every entry, as
           IDENTIFIER[PID]: MESSAGE      e.g.  api[2211]: slow request ...
  syslog   var/log/syslog: the text after the host name, as it is
           (e.g. CRON[31234]: (root) CMD (...) or kernel: [...] Out of memory...).
           rsyslog copies every journal entry into syslog. Leave out those
           copies: a syslog line with the same TIME and the same text as a
           journal entry is not a separate event.
  nginx    var/log/nginx/access.log: only responses with status 500 or higher, as
           METHOD URI STATUS             e.g.  GET /api/v1/orders?page=2 502
  app      var/log/api/app.log: only WARN and ERROR lines, as
           LEVEL message                 e.g.  ERROR db pool exhausted ...

Order: by TIME, oldest first. Events with the same TIME stay in the order
journal, syslog, nginx, app, and within one source in the order of its file.
EOF
