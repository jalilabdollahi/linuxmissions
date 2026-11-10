#!/bin/bash
# A live key leaked. Copies: plain files (some hidden), a gzipped log, a
# tarball member, a base64 Kubernetes Secret, a .bash_history, and a .env
# where the key is split by a backslash line continuation. Decoys: another
# pk_live_ key, a pk_test_ key, an archive without the key.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
python3 - <<'PY'
import base64, gzip, hashlib, io, json, os, random, shutil, tarfile
R = random.Random()
AL = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
def tok(n): return "".join(R.choice(AL) for _ in range(n))
KEY = "pk_live_" + tok(24)
OTHER = "pk_live_" + tok(24)
TEST = "pk_test_" + tok(24)
cut = R.randint(14, 26)
half1, half2 = KEY[:cut], KEY[cut:]
b64 = base64.b64encode(KEY.encode()).decode()
files = {}
plain_pool = {
    "site/app/settings.ini": "[payments]\nprovider = stripe\npublishable_key = %s\nretries = 3\n; fallback\nbackup_key = %s\n" % (KEY, KEY),
    "site/docs/README-setup.md": "# Setup\n\nExport the key before the first run:\n\n    export PAYMENTS_KEY=%s\n\nThen `make run`.\n" % KEY,
    "site/.notes/old-config.txt": "migrated 2026-03\nkey=%s\nowner=billing\n" % KEY,
    "site/src/payments.py": "import os\n\nPUBLISHABLE = \"%s\"\n\ndef charge(amount):\n    return {\"key\": PUBLISHABLE, \"amount\": amount}\n" % KEY,
    "site/.github/ci-notes.yml": "env:\n  PAYMENTS_KEY: %s\n  REGION: eu-west\n" % KEY,
}
plain = R.sample(sorted(plain_pool), 3)
for p in plain: files[p] = plain_pool[p]
leaks = list(plain)
files["site/src/payments_test.py"] = "TEST_KEY = \"%s\"\n" % TEST
files["site/docs/pricing.md"] = "Partner account (not ours) uses %s for its own checkout.\n" % OTHER
files["site/README.md"] = "# shop\nSee docs/.\n"
files["site/app/db.ini"] = "[db]\nhost=db-%d.internal\n" % R.randint(1, 9)
# hidden .env with a continued line
env = "APP_ENV=production\nPAYMENTS_KEY=%s\\\n%s\nLOG_LEVEL=info\n" % (half1, half2)
files["site/deploy/.env"] = env; leaks.append("site/deploy/.env")
# k8s secret
sec = "apiVersion: v1\nkind: Secret\nmetadata:\n  name: payments\ndata:\n  db-password: %s\n  stripe-key: %s\n  region: %s\n" % (
    base64.b64encode(tok(14).encode()).decode(), b64, base64.b64encode(b"eu-west").decode())
files["site/deploy/secret.yaml"] = sec; leaks.append("site/deploy/secret.yaml")
# bash history
hist = "ls\ncd /srv/shop\ncurl -s -H 'Authorization: Bearer %s' https://api.example.invalid/v1/balance\nhistory | tail\nexit\n" % KEY
files["site/home/deploy/.bash_history"] = hist; leaks.append("site/home/deploy/.bash_history")
for p, c in files.items():
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(c)
# archives (binary, must not change)
os.makedirs("site/logs", exist_ok=True); os.makedirs("site/backups", exist_ok=True)
log = "".join("2026-11-0%d 12:%02d:00 INFO charge ok amount=%d\n" % (R.randint(1, 9), i, R.randint(5, 900)) for i in range(60))
log += "2026-11-04 12:59:00 DEBUG request headers X-Key: %s\n" % KEY
with gzip.open("site/logs/app.log.3.gz", "wb") as f: f.write(log.encode())
leaks.append("site/logs/app.log.3.gz")
with gzip.open("site/logs/app.log.4.gz", "wb") as f: f.write(log.replace(KEY, "pk_live_" + tok(24)).encode())
members = {"conf/prod.env": "PAYMENTS_KEY=%s\nMODE=prod\n" % KEY, "conf/dev.env": "PAYMENTS_KEY=%s\n" % TEST, "data/orders.csv": "id,amount\n1,10\n2,20\n"}
with tarfile.open("site/backups/site-2026-10.tgz", "w:gz") as t:
    for n, c in members.items():
        ti = tarfile.TarInfo(n); b = c.encode(); ti.size = len(b); ti.mtime = 1790000000; t.addfile(ti, io.BytesIO(b))
leaks.append("site/backups/site-2026-10.tgz:conf/prod.env")
with tarfile.open("site/backups/site-2026-09.tgz", "w:gz") as t:
    for n, c in {"conf/prod.env": "PAYMENTS_KEY=%s\n" % OTHER}.items():
        ti = tarfile.TarInfo(n); b = c.encode(); ti.size = len(b); ti.mtime = 1790000000; t.addfile(ti, io.BytesIO(b))
os.makedirs(".lm-state/orig")
for p in files:
    d = os.path.join(".lm-state/orig", p); os.makedirs(os.path.dirname(d), exist_ok=True); shutil.copy(p, d)
st = {"key": KEY, "half1": half1, "half2": half2, "b64": b64, "leaks": sorted(leaks), "leakfiles": sorted(set(l for l in leaks if ":" not in l and not l.endswith(".gz")))}
json.dump(st, open(".lm-state/truth.json", "w"))
man = []
for root, _, fs in os.walk("site"):
    for f in fs:
        p = os.path.join(root, f)
        man.append("%s  %s" % (hashlib.sha256(open(p, "rb").read()).hexdigest(), p))
open(".lm-state/all.sum", "w").write("\n".join(sorted(man, key=lambda s: s.split("  ", 1)[1])) + "\n")
open("TICKET.md", "w").write("""# Leaked key

The paste-site report (excerpt):

    ...publishable key in a public paste: %s

That key is ours and must be treated as burned. Before it is revoked:
find every place it still sits under `site/` (our tree, including hidden
files, archives and encoded copies) and list them in `leaks.txt`, one per
line: the path, or `archive:member` for something inside a tar archive
(paths relative to this folder, e.g. `site/src/x.py`). Other keys that only
look similar are not ours.
""" % KEY)
PY
