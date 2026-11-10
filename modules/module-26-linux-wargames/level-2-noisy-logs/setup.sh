#!/bin/bash
# A running app logs at debug because app.env.d/zz-debug.env overrides
# app.env; its log is huge; rotate.conf has a typo, points at the wrong file
# and has no copytruncate/HUP, so rotation could never work for this process.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p app/app.env.d app/old .lm-state
cat > app/app.py <<'PY'
#!/usr/bin/env python3
# Toy service: reads app.env, then app.env.d/*.env in name order (later wins).
# SIGHUP re-reads the config and reopens the log file. Exits after 3 hours.
import glob, os, signal, sys, time
conf = os.environ["APP_CONF_DIR"]
logpath = os.path.join(conf, "app.log")
RANK = {"debug": 0, "info": 1, "warn": 2, "error": 3}
reload_flag = [True]
def load():
    level = "info"
    for f in [os.path.join(conf, "app.env")] + sorted(glob.glob(os.path.join(conf, "app.env.d", "*.env"))):
        try:
            for line in open(f):
                line = line.strip()
                if line.startswith("LOG_LEVEL="):
                    level = line.split("=", 1)[1].strip().lower()
        except OSError:
            pass
    return level if level in RANK else "info"
signal.signal(signal.SIGHUP, lambda *a: reload_flag.__setitem__(0, True))
open(os.path.join(conf, "app.pid"), "w").write(str(os.getpid()))
fd = None
level = "info"
start = time.time()
n = 0
while time.time() - start < 3 * 3600:
    if reload_flag[0]:
        reload_flag[0] = False
        level = load()
        if fd is not None:
            os.close(fd)
        fd = os.open(logpath, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
    n += 1
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    out = []
    if RANK[level] <= 0:
        out.append("%s DEBUG cache probe key=%08x ttl=%d hit=%d path=/internal/session/refresh" % (ts, n * 2654435761 % 2**32, n % 600, n % 2))
    if n % 5 == 0 and RANK[level] <= 2:
        out.append("%s WARN queue depth %d above soft limit 50" % (ts, 50 + n % 17))
    if out:
        try:
            os.write(fd, ("\n".join(out) + "\n").encode())
        except OSError:
            pass
    time.sleep(0.01)
PY
cat > app/app.env <<'EOF2'
# application settings
LOG_LEVEL=warn
WORKERS=4
EOF2
echo "MAX_CONN=200" > app/app.env.d/10-limits.env
printf '# temporary: trace the session bug (ticket 4471)\nLOG_LEVEL=debug\n' > app/app.env.d/zz-debug.env
python3 - <<'PY'
import random
R = random.Random()
with open("app/app.log", "w") as f:
    for i in range(55000):
        f.write("2026-11-10 0%d:%02d:%02d DEBUG cache probe key=%08x ttl=%d hit=%d path=/internal/session/refresh\n" % (R.randint(0, 9), R.randint(0, 59), R.randint(0, 59), R.getrandbits(32), R.randint(0, 599), R.randint(0, 1)))
PY
typo=$(shuf -n1 -e compres rotat missingk)
case $typo in
  compres) opts="    size 5M\n    rotate 4\n    compres\n    missingok" ;;
  rotat)   opts="    size 5M\n    rotat 4\n    compress\n    missingok" ;;
  missingk) opts="    size 5M\n    rotate 4\n    compress\n    missingk" ;;
esac
{
  echo "# rotate the app log (ticket 4471: disk was full again)"
  echo "$SANDBOX/app/logs/app.log {"
  printf "$opts\n"
  echo "}"
} > rotate.conf
: > logrotate.state
cat > TICKET.md <<'MD'
# Volume at 95 %

`app.log` grows about a megabyte a minute. The app (started by the init
script, `app/app.py`) must keep running; restarting it drops customer
sessions. The log may be emptied, not deleted blindly.
MD
APP_CONF_DIR="$SANDBOX/app" setsid python3 "$SANDBOX/app/app.py" >/dev/null 2>&1 < /dev/null &
for i in $(seq 50); do [ -s app/app.pid ] && break; sleep 0.1; done
cp app/app.pid .lm-state/pid
sleep 0.5
