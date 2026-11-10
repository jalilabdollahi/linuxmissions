#!/bin/bash
# 502 at 03:10, capstone. Story (Europe/Berlin, UTC+1, Nov 10; the clock is
# frozen at 03:22 local):
#   - a random "batch" unit (CAUSE) gets LOG_LEVEL=debug in /etc/CAUSE/env,
#     either by hand (trigger=config-change: sudo sed + restart) or by a
#     pipeline that rewrote the file (trigger=deploy). It then writes a
#     huge debug.log and fills /var;
#   - the FIRST error (priority <= 3) in the journal comes from postgresql
#     (ENOSPC), then api loses its session files, crash-loops and hits its
#     start limit, and nginx answers 502 (the access log has them, plus
#     decoys: 502s before the incident, 504/503, "502" in a path and in a
#     size field);
#   - api is the loudest unit but only a victim.
# Evidence: export/journal.json (journalctl -o json, epoch microseconds),
# var/log/nginx/access.log (local time +0100), dmesg.txt (dmesg
# --time-format iso), df-snapshot.txt. Live state: mock systemctl in bin/.
# The debug.log is a sparse file (apparent size), the "disk" is 20 GiB:
# api's start-up check sums the apparent sizes under var/. Names, times and
# counts are random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin .lm .lm-state export etc var/log/nginx var/lib/postgresql var/lib/api opt/api/bin opt/nginx/sbin opt/postgresql/bin opt/batch/bin \
  etc/systemd/system/multi-user.target.wants var/log/journal
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo web-02 > etc/hostname
echo Europe/Berlin > etc/timezone
ln -s /usr/share/zoneinfo/Europe/Berlin etc/localtime

python3 - "$RANDOM$$" <<'PY'
import json, os, random, sys, uuid
from datetime import datetime, timedelta, timezone

R = random.Random(int(sys.argv[1]))
TZ = timezone(timedelta(hours=1))
HOST = "web-02"
BOOT = uuid.UUID(int=R.getrandbits(128)).hex
CAUSE = R.choice(["etl-sync", "report-builder", "search-indexer", "metrics-collector"])
TRIGGER = R.choice(["config-change", "deploy"])
CAP = 20 * 1024 ** 3

def L(h, m, s=0, frac=0.0):
    return datetime(2026, 11, 10, h, m, int(s), tzinfo=TZ).timestamp() + (s - int(s)) + frac

t_cfg = L(2, R.randint(44, 52), R.randint(0, 59))
t_first = L(3, R.randint(2, 6), R.randint(0, 59), R.random())          # first err: postgresql
t_api = t_first + R.randint(18, 40) + R.random()                         # api's first error
t_limit = t_api + R.randint(14, 22)                                      # api start-limit-hit
t_cap_end = L(3, 20, 0)                                                  # logs/capture end

E = []
def J(t, ident, msg, prio, unit, pid=None, sysunit_field="_SYSTEMD_UNIT"):
    e = {"__REALTIME_TIMESTAMP": str(int(t * 1e6)), "_BOOT_ID": BOOT, "_HOSTNAME": HOST, "PRIORITY": str(prio),
         "SYSLOG_IDENTIFIER": ident, "MESSAGE": msg, "_PID": str(pid or R.randint(300, 9000))}
    if ident == "systemd":
        e["UNIT"] = unit
        e["_PID"] = "1"
    else:
        e[sysunit_field] = unit
    E.append(e)

pg_pid = R.randint(700, 800); api_pid = R.randint(2000, 2999); ngx_pid = R.randint(600, 690)
cause_pid = R.randint(5000, 5999)

# --- background, 02:30 -> 03:20 -----------------------------------------
t = L(2, 30, 3)
while t < t_cap_end:
    if t < t_api:
        J(t, "api", "metrics: %d req/min, p95 %d ms, pool %d/20" % (R.randint(380, 520), R.randint(40, 90), R.randint(3, 11)), 6, "api.service", api_pid)
    J(t + 0.4, "CRON", "(root) CMD (command -v debian-sa1 > /dev/null && debian-sa1 1 1)", 6, "cron.service", R.randint(20000, 29999))
    t += 600 if t > L(2, 30, 3) else 600
for m in range(30, 80, 4):
    t = L(2, 30) + (m - 30) * 60 + R.randint(0, 59)
    if t < t_cap_end:
        J(t, "postgresql", "checkpoint complete: wrote %d buffers (%.1f%%); 0 WAL file(s) added, 0 removed, %d recycled" % (R.randint(800, 4000), R.uniform(2, 15), R.randint(1, 4)), 6, "postgresql.service", pg_pid)
for m in range(6):
    J(L(2, 31) + R.randint(0, 1700), "sshd", "Accepted publickey for deploy from 10.0.9.%d port %d ssh2: ED25519 SHA256:q1Xb" % (R.randint(2, 40), R.randint(40000, 60000)), 6, "ssh.service", R.randint(30000, 39999))

# --- the cause -------------------------------------------------------------
J(t_cfg - 600, CAUSE, "%s: heartbeat ok, LOG_LEVEL=info" % CAUSE, 6, CAUSE + ".service", cause_pid)
if TRIGGER == "config-change":
    J(t_cfg - 30, "sudo", "  ops-marco : TTY=pts/2 ; PWD=/home/ops-marco ; USER=root ; COMMAND=/usr/bin/sed -i s/^LOG_LEVEL=info/LOG_LEVEL=debug/ /etc/%s/env" % CAUSE, 5, "session-11.scope", R.randint(9000, 9999))
    J(t_cfg - 12, "sudo", "  ops-marco : TTY=pts/2 ; PWD=/home/ops-marco ; USER=root ; COMMAND=/usr/bin/systemctl restart %s.service" % CAUSE, 5, "session-11.scope", R.randint(9000, 9999))
else:
    rel = "2.%d.%d" % (R.randint(10, 19), R.randint(0, 9))
    J(t_cfg - 40, "deploy-agent", "pipeline #%d: installing %s %s on web-02 (playbook release.yml, tag v%s)" % (R.randint(4000, 4900), CAUSE, rel, rel), 6, "deploy-agent.service", R.randint(800, 899))
    J(t_cfg - 30, "deploy-agent", "rendered /etc/%s/env from profile 'staging' (LOG_LEVEL=debug)" % CAUSE, 6, "deploy-agent.service", R.randint(800, 899))
    J(t_cfg - 12, "deploy-agent", "restarting %s.service" % CAUSE, 6, "deploy-agent.service", R.randint(800, 899))
J(t_cfg - 11.5, "systemd", "Stopping %s.service - %s batch worker..." % (CAUSE, CAUSE), 6, CAUSE + ".service")
J(t_cfg - 11, "systemd", "%s.service: Deactivated successfully." % CAUSE, 6, CAUSE + ".service")
J(t_cfg - 0.5, "systemd", "Started %s.service - %s batch worker." % (CAUSE, CAUSE), 6, CAUSE + ".service")
cause_pid += 41
J(t_cfg, CAUSE, "%s: starting, LOG_LEVEL=debug" % CAUSE, 6, CAUSE + ".service", cause_pid)
t = t_cfg + 300
gib = 0
while t < t_first - 20:
    gib += R.uniform(3.2, 4.4)
    J(t, CAUSE, "%s: wrote %.1f GiB to /var/log/%s/debug.log in the last 5 min" % (CAUSE, gib, CAUSE), 4, CAUSE + ".service", cause_pid)
    t += 300

# --- the symptoms -----------------------------------------------------------
t = t_first
J(t, "postgresql", 'ERROR:  could not write to file "pg_wal/xlogtemp.%d": No space left on device' % pg_pid, 3, "postgresql.service", pg_pid)
J(t + 0.2, "postgresql", "PANIC:  could not write to file \"pg_wal/xlogtemp.%d\": No space left on device" % pg_pid, 2, "postgresql.service", pg_pid)
t = t_first + 15
while t < t_api - 1:
    J(t, "postgresql", 'ERROR:  could not extend file "base/16384/%d": No space left on device' % R.randint(16000, 30000), 3, "postgresql.service", pg_pid)
    t += R.randint(10, 20)
t = t_api
for i in range(R.randint(60, 90)):
    J(t, "api", "ERROR session write failed: [Errno 28] No space left on device: '/var/lib/api/sessions/%s'" % uuid.UUID(int=R.getrandbits(128)).hex[:12], 3, "api.service", api_pid)
    t += R.uniform(0.05, 0.3)
t_crash = t
npid = api_pid
for i in range(1, 7):
    tc = t_crash + (i - 1) * 2.1
    npid += 1
    J(tc, "api", "api: cannot create session directory /var/lib/api/sessions: No space left on device", 3, "api.service", npid)
    J(tc + 0.01, "systemd", "api.service: Main process exited, code=exited, status=1/FAILURE", 5, "api.service")
    J(tc + 0.02, "systemd", "api.service: Failed with result 'exit-code'.", 4, "api.service")
    if i < 6:
        J(tc + 2.0, "systemd", "api.service: Scheduled restart job, restart counter is at %d." % i, 6, "api.service")
        J(tc + 2.05, "systemd", "Started api.service - Orders API.", 6, "api.service")
    else:
        J(tc + 2.0, "systemd", "api.service: Start request repeated too quickly.", 3, "api.service")
        J(tc + 2.01, "systemd", "api.service: Failed with result 'start-limit-hit'.", 3, "api.service")
        J(tc + 2.02, "systemd", "Failed to start api.service - Orders API.", 3, "api.service")
t_api_dead = t_crash + 5 * 2.1 + 2
t = t_api + 1
while t < t_cap_end - 5:
    if R.random() < 0.8:
        J(t, "nginx", "connect() failed (111: Connection refused) while connecting to upstream, client: 10.0.4.%d, server: _, request: \"GET /api/v1/orders HTTP/1.1\", upstream: \"http://127.0.0.1:8080/api/v1/orders\", host: \"shop.example\"" % R.randint(2, 250), 3, "nginx.service", ngx_pid)
    t += R.uniform(15, 40)
J(L(3, 10, 5), "pagerduty-agent", "alert triggered: api 5xx ratio above 50% for 5 min (incident INC-9051)", 4, "pd-agent.service", R.randint(900, 990))

E.sort(key=lambda e: int(e["__REALTIME_TIMESTAMP"]))
with open("export/journal.json", "w") as f:
    for e in E:
        f.write(json.dumps(e) + "\n")

# --- nginx access log ------------------------------------------------------
CLIENTS = ["10.0.4.%d" % R.randint(2, 250) for _ in range(14)]
PATHS = ["/api/v1/orders", "/api/v1/orders?page=2", "/api/v1/cart", "/api/v1/checkout", "/api/v1/products?q=lamp", "/api/v1/customers/me"]
STATIC = ["/static/app.css", "/static/app.js", "/favicon.ico", "/healthz"]
UAS = ['"Mozilla/5.0 (X11; Linux x86_64) Firefox/131.0"', '"okhttp/4.12.0"', '"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X)"', '"kube-probe/1.30"']
MON = "Nov"
lines = []
def N(t, status, path, size=None, method="GET"):
    ts = datetime.fromtimestamp(t, TZ).strftime("%d/%b/%Y:%H:%M:%S +0100")
    if size is None:
        size = {502: 157, 504: 167, 503: 190}.get(status, R.randint(150, 9000))
    lines.append((t, '%s - - [%s] "%s %s HTTP/1.1" %d %d "-" %s' % (R.choice(CLIENTS), ts, method, path, status, size, R.choice(UAS))))
n502 = 0
t = L(2, 30, 0)
while t < t_cap_end:
    t += R.expovariate(1 / 2.6)
    if t >= t_cap_end:
        break
    api = R.random() < 0.8
    path = R.choice(PATHS) if api else R.choice(STATIC)
    if t >= t_api + 3 and api:
        r = R.random()
        if r < 0.93:
            N(t, 502, path); n502 += 1
        elif r < 0.97:
            N(t, 504, path)
        else:
            N(t, 503, path)
    else:
        N(t, R.choice([200, 200, 200, 200, 304, 404]) if api else 200, path, method="POST" if path in ("/api/v1/cart", "/api/v1/checkout") else "GET")
# decoys: path/size containing 502 (status 200/404), and an earlier 502 blip
for _ in range(4):
    N(L(2, R.randint(31, 59), R.randint(0, 59)), 200, "/api/v1/orders/502")
for _ in range(3):
    N(L(2, R.randint(31, 59), R.randint(0, 59)), 200, R.choice(PATHS), size=502)
for _ in range(5):
    N(t_api + 5 + R.randint(0, 600), 404, "/api/v1/orders/%d502" % R.randint(1, 9))
for _ in range(3):
    N(L(2, 41, R.randint(0, 59)), 502, R.choice(PATHS))      # an earlier, unrelated blip (before the first error)
lines.sort(key=lambda x: x[0])
with open("var/log/nginx/access.log", "w") as f:
    for _, l in lines:
        f.write(l + "\n")
# the truth for the validator
want_502 = sum(1 for t, l in lines if int(t) >= int(t_first) and ' 502 ' in l.split('"')[2][:6])
first_utc = datetime.fromtimestamp(int(t_first), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# --- dmesg capture ----------------------------------------------------------
def D(t, msg):
    return "%s,%06d+01:00 %s" % (datetime.fromtimestamp(int(t), TZ).strftime("%Y-%m-%dT%H:%M:%S"), int((t % 1) * 1e6), msg)
dm = []
dm.append(D(L(2, 30, 1.5), "audit: type=1400 audit(1794285001.512:41): apparmor=\"STATUS\" operation=\"profile_replace\" profile=\"unconfined\" name=\"nvidia_modprobe\" pid=%d comm=\"apparmor_parser\"" % R.randint(9000, 9999)))
dm.append(D(L(2, 36, 22.1), "TCP: request_sock_TCP: Possible SYN flooding on port 443. Sending cookies.  Check SNMP counters."))
dm.append(D(L(2, 52, 8.4), "perf: interrupt took too long (3140 > 3126), lowering kernel.perf_event_max_sample_rate to 63600"))
dm.append(D(t_first + 3.1, "EXT4-fs warning (device sda2): ext4_dx_add_entry:2432: Directory (ino: 1310722) index full, reach max htree level :2"))
dm.append(D(t_first + 3.2, "EXT4-fs (sda2): Delayed block allocation failed for inode %d at logical offset 0 with max blocks 2 with error 28" % R.randint(1310730, 1310999)))
dm.append(D(t_first + 3.2, "EXT4-fs (sda2): This should not happen!! Data will be lost"))
for i in range(R.randint(3, 6)):
    dm.append(D(t_first + 20 + i * R.randint(30, 60), "EXT4-fs (sda2): Delayed block allocation failed for inode %d at logical offset %d with max blocks 2 with error 28" % (R.randint(1310730, 1310999), R.randint(0, 2000))))
dm.append(D(L(3, 9, 41.8), "TCP: request_sock_TCP: Possible SYN flooding on port 443. Sending cookies.  Check SNMP counters."))
dm.sort()
with open("dmesg.txt", "w") as f:
    f.write("\n".join(dm) + "\n")

# --- sizes and df -----------------------------------------------------------
wal_arch = 1536 * 1024 ** 2
small = 14 * 1024 ** 2
debug_size = int(CAP * 0.987) - wal_arch - small
os.makedirs("var/log/%s" % CAUSE, exist_ok=True)
os.makedirs("etc/%s" % CAUSE, exist_ok=True)
with open("var/log/%s/debug.log" % CAUSE, "wb") as f:
    f.truncate(debug_size)
with open("var/lib/postgresql/wal-archive.bak", "wb") as f:
    f.truncate(wal_arch)
G = lambda b: "%.1fG" % (b / 1024 ** 3)
used = debug_size + wal_arch + small
open("df-snapshot.txt", "w").write(
"""$ date; df -h /var
%s
Filesystem      Size  Used Avail Use%% Mounted on
/dev/sda2        20G   %s  %s  %d%% /var

$ df -i /var
Filesystem      Inodes  IUsed   IFree IUse%% Mounted on
/dev/sda2      1310720  61422 1249298    5%% /var

$ du -x --apparent-size -h --max-depth=2 /var | sort -h | tail -6
%s\t/var/lib/postgresql
%s\t/var/lib
%s\t/var/log/%s
%s\t/var/log
%s\t/var
""" % (datetime.fromtimestamp(L(3, 12, 4), TZ).strftime("%a %b %e %H:%M:%S CET %Y"), G(used), G(CAP - used), round(used * 100 / CAP),
       G(wal_arch), G(wal_arch + 3 * 1024 ** 2), G(debug_size + 2 * 1024 ** 2), CAUSE, G(debug_size + small), G(used)))

with open(".lm-state/truth", "w") as f:
    f.write("CAUSE=%s\nTRIGGER=%s\nFIRST=%s\nN502=%d\nCAP=%d\n" % (CAUSE, TRIGGER, first_utc, want_502, CAP))
with open(".lm-state/cfgtime", "w") as f:
    f.write(datetime.fromtimestamp(t_cfg, TZ).strftime("%Y-%m-%d %H:%M:%S") + "\n")
PY
. .lm-state/truth

# --- the units --------------------------------------------------------------
cat > opt/batch/bin/batch <<'LMEND'
#!/bin/bash
# batch worker (stand-in). With LOG_LEVEL=debug it dumps every record it
# handles into /var/log/NAME/debug.log, forever.
NAME="$1"
ROOT="${0%/opt/batch/bin/batch}"
echo "$NAME: starting, LOG_LEVEL=${LOG_LEVEL:-info}"
while :; do
  if [ "$LOG_LEVEL" = debug ]; then
    echo "DEBUG record batch=$RANDOM rows=$RANDOM payload=$(printf '%0200d' 0)" >> "$ROOT/var/log/$NAME/debug.log"
  fi
  sleep 1
done
LMEND
cat > opt/api/bin/api <<'LMEND'
#!/usr/bin/env python3
# api (stand-in): needs room under /var for its session files; the lab's
# disk is 20 GiB and files are counted by apparent size.
import os, sys, time
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[0])))))
cap = int(open(os.path.join(root, ".lm-state", "disk-capacity")).read())
used = 0
for d, _, files in os.walk(os.path.join(root, "var")):
    for f in files:
        try:
            used += os.path.getsize(os.path.join(d, f))
        except OSError:
            pass
if used > cap * 0.97:
    print("api: cannot create session directory /var/lib/api/sessions: No space left on device", file=sys.stderr, flush=True)
    sys.exit(1)
print("api: serving on :8080, sessions in /var/lib/api/sessions", flush=True)
while True:
    time.sleep(5)
LMEND
cat > opt/nginx/sbin/nginx <<'LMEND'
#!/bin/bash
echo "nginx: master process started"
while :; do sleep 5; done
LMEND
cat > opt/postgresql/bin/postgres <<'LMEND'
#!/bin/bash
echo "postgres: database system is ready to accept connections"
while :; do sleep 5; done
LMEND
chmod +x opt/*/bin/* opt/nginx/sbin/nginx
echo "$CAP" > .lm-state/disk-capacity

mkunit() {   # name description exec [extra service lines...]
  local name=$1 desc=$2 exec=$3; shift 3
  { printf '[Unit]\nDescription=%s\nAfter=network.target\n\n[Service]\nType=simple\n' "$desc"
    for l in "$@"; do printf '%s\n' "$l"; done
    printf 'ExecStart=%s\n\n[Install]\nWantedBy=multi-user.target\n' "$exec"
  } > etc/systemd/system/$name.service
  ln -s /etc/systemd/system/$name.service etc/systemd/system/multi-user.target.wants/$name.service
}
mkunit nginx "nginx web server and reverse proxy" "/opt/nginx/sbin/nginx -g 'daemon off;'" "Restart=on-failure"
mkunit postgresql "PostgreSQL database" "/opt/postgresql/bin/postgres -D /var/lib/postgresql" "Restart=on-failure"
mkunit api "Orders API" "/opt/api/bin/api" "Restart=on-failure" "RestartSec=2"
mkunit "$CAUSE" "$CAUSE batch worker" "/opt/batch/bin/batch $CAUSE" "EnvironmentFile=/etc/$CAUSE/env" "Restart=on-failure"
printf '# managed by config management\nLOG_LEVEL=debug\nBATCH_SIZE=500\n' > etc/$CAUSE/env

bin/systemctl daemon-reload
echo "2026-11-09 22:00:00" > .lm/now
bin/systemctl start nginx.service postgresql.service
cfg=$(cat .lm-state/cfgtime)
echo "$cfg" > .lm/now
bin/systemctl start "$CAUSE.service"
bin/systemctl show -P MainPID "$CAUSE.service" > .lm-state/cause.pid
echo "2026-11-10 03:22:00" > .lm/now

# the state api was left in
cat > .lm/systemd/units/api.service.state <<'LMEND'
ActiveState=failed
SubState=failed
Result=start-limit-hit
ExecMainPID=2411
ExecMainCode=exited
ExecMainStatus=1
MainPID=0
NRestarts=5
LMEND
fst=$(python3 -c "
import sys
from datetime import datetime, timezone
print(datetime.strptime('$FIRST','%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc).timestamp()+45)")
printf 'StateChangeTimestamp=@%s\nInactiveEnterTimestamp=@%s\n' "${fst%.*}" "${fst%.*}" >> .lm/systemd/units/api.service.state
bin/systemctl daemon-reload

sha256sum export/journal.json var/log/nginx/access.log dmesg.txt df-snapshot.txt > .lm-state/sources.sum

cat > INCIDENT.md <<'LMEND'
# INC-9051: the API returned 502 at 03:10 (web-02)

Pager: "api 5xx ratio above 50% for 5 min". web-02 runs in Europe/Berlin
(UTC+1 in November); the frozen clock says 03:22. Evidence, all in this folder:

  export/journal.json         journalctl -o json export of the main units
                              (read it with: journalctl --file=export/journal.json)
  var/log/nginx/access.log    nginx combined log, local time (+0100)
  dmesg.txt                   kernel messages (dmesg --time-format iso)
  df-snapshot.txt             df / du captured at 03:12
  systemctl, journalctl       mocks: the live state of the units (the sandbox is /)

Note: files in this lab are sparse; the sizes `ls -l` shows are the real ones
(du without --apparent-size shows almost nothing).

Your job: (1) fix it, (2) fill in incident.txt.

Fix: the unit that CAUSED the incident must be healthy again (fix its
configuration, remove the damage it did, restart it), and api must be running.
Do not delete anything that is not part of the damage; nginx and postgresql
must keep running.

incident.txt, four lines, exactly this form (a template is already there):

  first_error_utc=   the earliest journal entry with priority err (3) or worse
                     in export/journal.json, in UTC, like 2026-11-10T02:04:41Z
  root_cause_unit=   the unit that caused it, like foo.service
  trigger=           what started it, ONE of: config-change, deploy, cron-job,
                     traffic-spike, hardware-fault, certificate-expiry
  failed_requests=   number of requests nginx answered with status 502 from
                     first_error_utc until the end of access.log
LMEND
printf 'first_error_utc=\nroot_cause_unit=\ntrigger=\nfailed_requests=\n' > incident.txt
