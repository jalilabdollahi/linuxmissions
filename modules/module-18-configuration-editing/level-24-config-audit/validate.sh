#!/bin/bash
# 1. the app's own check passes, 2. every file's required values are checked independently of that
# check (so "make it parse" by deleting a setting does not work), 3. the running app answers on its port
# with the version string.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

out=$(bin/app --check-config 2>&1)
if [ $? -ne 0 ]; then
  echo "❌ ${out}"
  exit 1
fi

python3 - "$SANDBOX" <<'PY'
import configparser, json, sys, yaml

sb = sys.argv[1]
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)
port = open(f"{sb}/.lm-state/port").read().strip()
ver = open(f"{sb}/.lm-state/version").read().strip()
key = open(f"{sb}/.lm-state/secret").read().strip()
d = f"{sb}/etc/app"

ini = configparser.ConfigParser(interpolation=None)
ini.read(f"{d}/app.ini")
want_ini = {("server", "host"): "127.0.0.1", ("server", "port"): port, ("server", "workers"): "4",
            ("database", "url"): "postgres://app:s3cret@db.local:5432/app", ("database", "pool_size"): "10",
            ("logging", "level"): "info"}
for (sec, k), v in want_ini.items():
    got = ini.get(sec, k, fallback=None)
    if got != v:
        fail(f"app.ini: [{sec}] {k} is {got!r}, MIGRATION.txt says {v!r}")

env = {}
for line in open(f"{d}/app.env").read().splitlines():
    if line.strip() and not line.startswith("#") and "=" in line:
        k, _, v = line.partition("=")
        env[k] = v.strip("\"'")
for k, v in (("APP_ENV", "production"), ("APP_VERSION", ver), ("SECRET_KEY", key), ("LOG_COLOR", "1")):
    if env.get(k) != v:
        fail(f"app.env: {k} is {env.get(k)!r}, expected {v!r}")

feats = json.load(open(f"{d}/features.json")).get("features")
if feats != {"search": True, "checkout": True, "beta_ui": False}:
    fail(f"features.json: the features are {feats}, MIGRATION.txt wants search on, checkout on, beta_ui off")

svc = yaml.safe_load(open(f"{d}/services.yml"))["services"]
if svc != {"cache": {"host": "127.0.0.1", "port": 6379}, "queue": {"host": "127.0.0.1", "port": 5672}}:
    fail(f"services.yml: the services are {svc}, expected cache 127.0.0.1:6379 and queue 127.0.0.1:5672")

hosts = {}
for line in open(f"{d}/hosts").read().splitlines():
    f = line.split("#", 1)[0].split()
    for n in f[1:]:
        hosts.setdefault(n, f[0])
for n, ip in (("localhost", "127.0.0.1"), ("db.local", "127.0.0.1"), ("cache.local", "127.0.0.1")):
    if hosts.get(n) != ip:
        fail(f"hosts: {n} resolves to {hosts.get(n)!r}, expected {ip}")
PY
[ $? -eq 0 ] || exit 1

PORT=$(cat .lm-state/port); VER=$(cat .lm-state/version)
body=$(curl -s --max-time 3 "http://127.0.0.1:$PORT/" 2>/dev/null)
if [ -z "$body" ]; then
  echo "❌ the configuration is right, but nothing answers on 127.0.0.1:$PORT: start the app"
  exit 1
fi
if [ "$body" != "linuxapp $VER" ]; then
  echo "❌ the app answers '$body' on port $PORT, expected 'linuxapp $VER': it was started before the files were right, restart it"
  exit 1
fi
echo "✅ the config check passes, every value is as migrated, and the app answers 'linuxapp $VER' on port $PORT"
exit 0
