#!/bin/bash
# tmp/ with a ~48 MB debug log that was deleted while `logger` still holds it open (du
# cannot see it), stale files (9+ days old) to clean, recent files to keep, and an
# `agent` process that holds an old lock file and an old unix socket (both must stay).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/app tmp/cache/sub recovered .lm-state
cat > opt/app/logger.py <<'PY'
#!/usr/bin/env python3
# Stand-in for an app that logs to tmp/app-debug.log and never closes it.
import sys, time
log = open(sys.argv[1], "ab")
print("logger running", flush=True)
while True:
    time.sleep(30)
PY
cat > opt/app/agent.py <<'PY'
#!/usr/bin/env python3
# Stand-in for a local agent: holds a lock file and listens on a unix socket.
import fcntl, os, socket, sys, time
lock = open(os.path.join(sys.argv[1], "agent.lock"), "w")
fcntl.flock(lock, fcntl.LOCK_EX)
s = socket.socket(socket.AF_UNIX); s.bind(os.path.join(sys.argv[1], "agent.sock")); s.listen(1)
while True:
    time.sleep(30)
PY
python3 - "$RANDOM$$" <<'PY'
import hashlib, os, random, sys
R = random.Random(int(sys.argv[1]))
words = ["cache miss", "retry", "queue depth", "flush", "token refresh", "gc pause", "conn reset", "slow query"]
block = "".join("2026-11-0%d 03:%02d:%02d DEBUG %-14s id=%08x lat=%dms\n" % (
    R.randint(1, 9), R.randint(0, 59), R.randint(0, 59), R.choice(words), R.getrandbits(32), R.randint(1, 900)) for _ in range(9000)).encode()
h = hashlib.sha256()
with open("tmp/app-debug.log", "wb") as f:
    for i in range(110):
        chunk = block + b"chunk %d\n" % i
        f.write(chunk); h.update(chunk)
open(".lm-state/sha", "w").write(h.hexdigest() + "\n")
def mk(path, size, days):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(bytes(R.getrandbits(8) for _ in range(min(size, 4096))) * max(1, size // 4096))
    t = os.stat(path).st_mtime - days * 86400 - R.randint(0, 20000)
    os.utime(path, (t, t))
stale = ["tmp/build-%d.log" % R.randint(1000, 4000), "tmp/cache/old-%d.dat" % R.randint(1, 99), "tmp/cache/sub/blob.bin",
         "tmp/.session-%x" % R.getrandbits(24), "tmp/report draft.tmp", "tmp/core.%d" % R.randint(2000, 30000), "tmp/upload-%d.part" % R.randint(1, 99)]
keep = ["tmp/build-current.log", "tmp/cache/fresh.dat", "tmp/.active-session", "tmp/notes today.txt", "tmp/cache/sub/latest.bin"]
for i, p in enumerate(stale):
    mk(p, R.choice([20000, 90000, 300000, 600000]), R.randint(9, 60))
for p in keep:
    mk(p, R.choice([5000, 40000, 200000]), R.choice([0, 1, 2, 3, 5, 6]))
open(".lm-state/stale", "w").write("\n".join(stale) + "\n")
open(".lm-state/keep", "w").write("\n".join(keep + ["tmp/agent.lock", "tmp/agent.sock"]) + "\n")
PY
python3 "$SANDBOX/opt/app/logger.py" "$SANDBOX/tmp/app-debug.log" >/dev/null 2>&1 &
echo $! > .lm-state/holder.pid
python3 "$SANDBOX/opt/app/agent.py" "$SANDBOX/tmp" >/dev/null 2>&1 &
echo $! > .lm-state/agent.pid
sleep 1
rm -f tmp/app-debug.log        # the log is now only reachable through the logger's descriptor
d=$((RANDOM % 8 + 12)); touch -d "$d days ago" tmp/agent.lock tmp/agent.sock
cat > TICKET.md <<'T'
# tmp/ usage alarm

The monitoring says tmp/ grew by about 50 MB since last week, but `du`
finds only a few MB in it. Find where the space went and save the lost debug
log as recovered/app-debug.log. Then clean tmp/ by policy: delete regular
files older than 7 days that nobody is using. Keep everything newer, and keep
whatever a live process is using. Finally stop the process that was
holding the lost file open.
T
