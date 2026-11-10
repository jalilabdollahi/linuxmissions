#!/bin/bash
# Roll Back /etc/app. Six nightly snapshots hold etc/app of the server. daily.0 and daily.1
# (and, randomly, daily.2) are unusable for different reasons the checker finds: a bad
# config, a world-readable secret, a dangling symlink. The newest good one is daily.K.
# The live sysroot/etc/app is the broken post-upgrade tree with extra files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p bin .lm-state
cat > bin/app <<'PYEOF'
#!/usr/bin/env python3
"""app (mock service binary): only the configuration checker is implemented.

usage: app --check-config [DIR]     check DIR (default sysroot/etc/app next to this tool)
Rules: app.conf must exist, hold `key = value` lines and `include conf.d/*.conf` lines;
only known keys are accepted; listen, data_dir, secret_file and db_host are required;
db_port, cache_ttl and workers are numbers; the secret file must exist and must not be
readable by group or others; symlinks inside DIR must resolve to a file inside DIR.
Exit status 0 when the configuration is valid, 1 otherwise.
"""
import glob, os, re, stat, sys
here = os.path.dirname(os.path.abspath(__file__))
if os.path.basename(here) == "bin": here = os.path.dirname(here)
args = sys.argv[1:]
if not args or args[0] != "--check-config" or len(args) > 2:
    print(__doc__.strip().splitlines()[0]); print("usage: app --check-config [DIR]"); sys.exit(2)
d = args[1] if len(args) == 2 else os.path.join(here, "sysroot", "etc", "app")
def err(m): print("app: error: " + m); sys.exit(1)
if not os.path.isfile(os.path.join(d, "app.conf")): err("%s/app.conf: no such file" % d)
KEYS = {"listen", "data_dir", "secret_file", "log_level", "db_host", "db_port", "cache_ttl", "workers"}
cfg = {}; nfiles = 0
def load(path, depth=0):
    global nfiles
    if depth > 2: err("includes nested too deep")
    nfiles += 1
    if not os.path.exists(path): err("%s: file does not exist (dangling include or link)" % os.path.relpath(path, d))
    for n, raw in enumerate(open(path).read().splitlines(), 1):
        s = raw.strip()
        if not s or s.startswith("#"): continue
        m = re.fullmatch(r"include\s+(\S+)", s)
        if m:
            for p in sorted(glob.glob(os.path.join(d, m.group(1)))): load(p, depth + 1)
            continue
        m = re.fullmatch(r"(\w+)\s*=\s*(.*)", s)
        if not m: err("%s:%d: syntax error" % (os.path.relpath(path, d), n))
        k, v = m.groups()
        if k not in KEYS: err("%s:%d: unknown key '%s'" % (os.path.relpath(path, d), n, k))
        cfg[k] = v
load(os.path.join(d, "app.conf"))
for k in ("listen", "data_dir", "secret_file", "db_host"):
    if k not in cfg: err("required key '%s' is not set" % k)
for k in ("db_port", "cache_ttl", "workers"):
    if k in cfg and not (cfg[k].isdigit() and 0 < int(cfg[k]) < 65536): err("%s: '%s' is not a valid number" % (k, cfg[k]))
if cfg.get("log_level", "info") not in ("debug", "info", "warn", "error"): err("log_level: unknown level '%s'" % cfg["log_level"])
sf = os.path.join(d, cfg["secret_file"])
if not os.path.isfile(sf): err("secret_file %s does not exist" % cfg["secret_file"])
mode = stat.S_IMODE(os.stat(sf).st_mode)
if mode & 0o077: err("%s is readable by group or others (mode %04o); it must be private" % (cfg["secret_file"], mode))
for root, dirs, files in os.walk(d):
    for name in dirs + files:
        p = os.path.join(root, name)
        if os.path.islink(p):
            real = os.path.realpath(p)
            if not os.path.exists(real): err("%s is a dangling symlink" % os.path.relpath(p, d))
            if not (real + "/").startswith(os.path.realpath(d) + "/"): err("%s points outside the config directory" % os.path.relpath(p, d))
print("app: configuration OK (%d file%s)" % (nfiles, "" if nfiles == 1 else "s")); sys.exit(0)
PYEOF
chmod +x bin/app; ln -sf bin/app app
python3 - <<'PYEOF'
import os, random, shutil, time
R = random.SystemRandom()
now = int(time.time())
def write(root, rel, text, mode):
    p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(text); os.chmod(p, mode)
def tree(root, spec):
    os.makedirs(root, exist_ok=True); os.chmod(root, 0o755)
    os.makedirs(os.path.join(root, "conf.d"), exist_ok=True); os.chmod(os.path.join(root, "conf.d"), 0o755)
    write(root, "app.conf", "# app main configuration\nlisten = 0.0.0.0:%d\ndata_dir = /var/lib/app\nsecret_file = secret.key\nlog_level = %s\ninclude conf.d/*.conf\n" % (spec["port"], spec["log"]), 0o644)
    write(root, "conf.d/10-db.conf", "db_host = %s\ndb_port = %d\n" % (spec["db"], spec["dbport"]), 0o644)
    write(root, "conf.d/20-cache.conf", "cache_ttl = %d\nworkers = %d\n" % (spec["ttl"], spec["workers"]), 0o644)
    write(root, "secret.key", spec["secret"] + "\n", spec.get("secretmode", 0o600))
    os.symlink("conf.d/20-cache.conf", os.path.join(root, "active.conf"))
def stamp(root, base):
    i = 0
    for dp, dn, fn in os.walk(root):
        for name in sorted(fn + [x for x in dn if os.path.islink(os.path.join(dp, x))]):
            p = os.path.join(dp, name); i += 1
            os.utime(p, (base + i * 37, base + i * 37), follow_symlinks=False)
dbs = ["db1.internal", "pg-primary.lan", "db-eu-1.internal", "postgres.svc"]
specs = []
for n in range(6):
    specs.append({"port": R.choice([8443, 9443, 8080, 8000]), "log": R.choice(["info", "warn", "debug"]), "db": R.choice(dbs),
                  "dbport": R.choice([5432, 5433, 6432]), "ttl": R.choice([60, 120, 300, 900]), "workers": R.choice([2, 4, 8]),
                  "secret": "".join(R.choice("0123456789abcdef") for _ in range(40))})
K = R.choice([2, 3])
bad = ["conf", "mode", "link"][:K]
R.shuffle(bad[:1]) if False else None
kinds = ["conf", "mode"] + (["link"] if K == 3 else [])
os.makedirs("snapshots")
for n in range(6):
    root = "snapshots/daily.%d/etc/app" % n
    s = dict(specs[n])
    if n >= 1 and n <= K - 1 and False: pass
    tree(root, s)
    if n < K:
        kind = kinds[n]
        if kind == "conf":
            v = R.choice(["typo", "port", "nodb"])
            p = os.path.join(root, "conf.d/10-db.conf"); t = open(p).read()
            if v == "typo": t = t.replace("db_port", "db_prot")
            elif v == "port": t = t.replace("db_port = ", "db_port = ").rstrip("\n") + "x\n"
            else: t = "# db_host moved to the vault\ndb_port = %d\n" % s["dbport"]
            open(p, "w").write(t)
        elif kind == "mode":
            os.chmod(os.path.join(root, "secret.key"), R.choice([0o644, 0o664, 0o640 | 0o004]))
        elif kind == "link":
            os.remove(os.path.join(root, "active.conf")); os.symlink("conf.d/30-tuning.conf", os.path.join(root, "active.conf"))
    # keep identical content across good snapshots with different mtimes
    stamp(root, now - (n + 1) * 86400 - R.randrange(0, 40000))
good = K
open(".lm-state/good", "w").write("daily.%d\n" % good)
# the live tree after the failed upgrade
live = "sysroot/etc/app"
tree(live, {"port": 9999, "log": "debug", "db": "db-new.internal", "dbport": 5432, "ttl": 30, "workers": 16, "secret": "".join(R.choice("0123456789abcdef") for _ in range(40)), "secretmode": 0o640})
write(live, "conf.d/90-upgrade.conf", "tls_mode = strict\n", 0o644)
write(live, "app.conf.dpkg-new", "# new default configuration shipped by the package\n", 0o644)
os.remove(os.path.join(live, "active.conf")); os.symlink("conf.d/90-upgrade.conf", os.path.join(live, "active.conf"))
stamp(live, now - 3600)
# the rest of the server must stay as it is
for rel, txt in (("sysroot/etc/hostname", "app-%02d\n" % R.randrange(1, 40)), ("sysroot/etc/hosts", "127.0.0.1 localhost\n"),
                 ("sysroot/var/lib/app/state.db", "".join(R.choice("abcdef") for _ in range(200)) + "\n"),
                 ("sysroot/etc/os-release", 'NAME="Ubuntu"\nVERSION_ID="24.04"\n')):
    os.makedirs(os.path.dirname(rel), exist_ok=True); open(rel, "w").write(txt)
PYEOF
find sysroot -path sysroot/etc/app -prune -o -type f -print | sort | xargs cksum > .lm-state/outside
cksum bin/app > .lm-state/sums
