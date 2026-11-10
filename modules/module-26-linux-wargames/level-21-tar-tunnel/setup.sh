#!/bin/bash
# Wargame 21: copy a tree through a text-only relay with a size limit.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf alpha bravo relay relay.log .lm
mkdir -p alpha bravo/inbox .lm
cat > relay <<'RELAY'
#!/usr/bin/env python3
# relay: the only link between alpha and bravo.
#   ./relay send [FILE]    send one message (stdin if no FILE)
# Limits: ASCII text only, lines of at most 76 characters, 64 KB per message.
# Messages show up in bravo/inbox/ under random names, in random order.
import os, secrets, sys, time, random
here = os.path.dirname(os.path.abspath(__file__))
MAXLINE, MAXMSG = 76, 65536
def log(s):
    with open(os.path.join(here, "relay.log"), "a") as f:
        f.write(time.strftime("%H:%M:%S ") + s + "\n")
def reject(why):
    log("REJECT " + why); sys.stderr.write("relay: rejected: " + why + "\n"); sys.exit(1)
if len(sys.argv) < 2 or sys.argv[1] != "send" or len(sys.argv) > 3:
    sys.stderr.write("usage: relay send [FILE]\n"); sys.exit(2)
data = open(sys.argv[2], "rb").read() if len(sys.argv) == 3 else sys.stdin.buffer.read()
if not data: reject("empty message")
if len(data) > MAXMSG: reject("message is %d bytes (max %d)" % (len(data), MAXMSG))
for n, line in enumerate(data.split(b"\n"), 1):
    if len(line) > MAXLINE: reject("line %d is %d characters (max %d)" % (n, len(line), MAXLINE))
    for b in line:
        if b >= 128 or (b < 32 and b != 9): reject("line %d has a non-text byte (0x%02x): the relay carries ASCII only" % (n, b))
name = os.path.join(here, "bravo", "inbox", "msg-" + secrets.token_hex(4))
with open(name, "wb") as f: f.write(data)
t = time.time() - random.randint(0, 3600); os.utime(name, (t, t))
log("OK bytes=%d lines=%d" % (len(data), data.count(b"\n")))
print("relay: delivered %d bytes" % len(data))
RELAY
chmod 755 relay
python3 - <<'PY'
import os, random, json, hashlib
rnd = random.Random(os.urandom(8))
base = "alpha/data"
for d in ("reports/archive", "bin", "cfg", "empty"): os.makedirs(f"{base}/{d}")
def put(path, data, mode, mt):
    with open(f"{base}/{path}", "wb") as f: f.write(data)
    os.chmod(f"{base}/{path}", mode); os.utime(f"{base}/{path}", (mt, mt))
mt = lambda: 1700000000 + rnd.randint(0, 60000000)
put("blob1.bin", os.urandom(rnd.randint(60000, 90000)), 0o644, mt())
put("blob2.bin", os.urandom(rnd.randint(60000, 90000)), 0o640, mt())
put("secret.key", os.urandom(2048), 0o600, mt())
put("bin/run.sh", b"#!/bin/sh\necho run\n", 0o755, mt())
put("cfg/app.conf", b"mode=prod\nworkers=4\n" * 30, 0o664, mt())
put("notes with space.txt", b"remember: keep the spaces\n", 0o644, mt())
put(".hidden", os.urandom(300), 0o600, mt())
put("zero.dat", b"", 0o644, mt())
csv = b"".join(b"%d,%d\n" % (i, rnd.randint(0, 99999)) for i in range(4000))
put("reports/2026-11.csv", csv, 0o644, mt())
os.link(f"{base}/reports/2026-11.csv", f"{base}/reports/archive/2026-11-copy.csv")
put("reports/2026-10.csv", os.urandom(30000), 0o644, mt())
os.symlink("reports/2026-11.csv", f"{base}/latest")
t = mt(); os.utime(f"{base}/latest", (t, t), follow_symlinks=False)
os.chmod(f"{base}/empty", 0o750)
# directory times last (children changed them)
for d in sorted([r for r, _, _ in os.walk(base)], reverse=True):
    t = mt(); os.utime(d, (t, t))
os.chmod(f"{base}/cfg", 0o775); 
man = {}; total = 0
for r, ds, fs in os.walk(base):
    for n in ds + fs:
        p = os.path.join(r, n); st = os.lstat(p); rel = os.path.relpath(p, base)
        e = {"mode": st.st_mode & 0o7777, "mtime": int(st.st_mtime), "nlink": st.st_nlink}
        if os.path.islink(p): e["type"] = "l"; e["target"] = os.readlink(p)
        elif os.path.isdir(p): e["type"] = "d"
        else:
            e["type"] = "f"; e["size"] = st.st_size; e["sha"] = hashlib.sha256(open(p, "rb").read()).hexdigest(); e["ino"] = st.st_ino
            total += st.st_size
        man[rel] = e
json.dump({"entries": man, "bytes": total}, open(".lm/manifest.json", "w"))
PY
exit 0
