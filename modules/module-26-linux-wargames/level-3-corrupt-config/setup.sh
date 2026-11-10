#!/bin/bash
# Friday's hand-edited config.json is broken four ways: merge-conflict
# markers around the intended change, a trailing comma, smart quotes, and a
# duplicate key that jq silently resolves to the wrong (last) value.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
cat > app <<'PY'
#!/usr/bin/env python3
"""orders-api config checker: ./app --check [file]"""
import json, sys
def pairs(items):
    seen = {}
    for k, v in items:
        if k in seen:
            raise ValueError("duplicate key %r" % k)
        seen[k] = v
    return seen
def main():
    if len(sys.argv) < 2 or sys.argv[1] != "--check":
        print("usage: ./app --check [config.json]"); return 2
    path = sys.argv[2] if len(sys.argv) > 2 else "config.json"
    try:
        text = open(path, encoding="utf-8").read()
        cfg = json.loads(text, object_pairs_hook=pairs)
    except json.JSONDecodeError as e:
        print("config error: %s: line %d, column %d: %s" % (path, e.lineno, e.colno, e.msg)); return 1
    except (ValueError, OSError) as e:
        print("config error: %s: %s" % (path, e)); return 1
    need = {("server", "port"): int, ("server", "host"): str, ("server", "timeout_ms"): int,
            ("db", "pool_size"): int, ("db", "url"): str}
    for (a, b), typ in need.items():
        if not isinstance(cfg.get(a), dict) or not isinstance(cfg[a].get(b), typ):
            print("config error: %s.%s missing or not a %s" % (a, b, typ.__name__)); return 1
    print("config ok: %s" % path); return 0
sys.exit(main())
PY
chmod 755 app
python3 - <<'PY'
import json, random
R = random.Random()
host = R.choice(["0.0.0.0", "10.20.0.%d" % R.randint(2, 9), "127.0.0.1"])
port = R.choice([8443, 9443, 8080, 7000 + R.randint(1, 99)])
timeout = R.choice([3000, 5000, 8000, 12000])
old_pool = R.choice([10, 20, 25, 40])
new_pool = old_pool + R.choice([30, 40, 60, 80])
dbhost = "db-%02d.internal" % R.randint(1, 20)
last = {
    "service": R.choice(["orders-api", "billing-api", "catalog-api"]),
    "server": {"host": host, "port": port, "timeout_ms": timeout, "keepalive": True},
    "db": {"url": "postgres://app@%s:5432/shop" % dbhost, "pool_size": old_pool, "ssl": True},
    "cache": {"ttl_s": R.choice([60, 300, 600]), "nodes": ["cache-1.internal", "cache-2.internal"]},
    "features": {"audit_log": False, "beta_ui": R.choice([True, False]), "debug_endpoints": False},
}
exp = json.loads(json.dumps(last))
exp["db"]["pool_size"] = new_pool
exp["features"]["audit_log"] = True
json.dump(last, open("config.json.last-good", "w"), indent=2); open("config.json.last-good", "a").write("\n")
json.dump(exp, open(".lm-state/expected.json", "w"), indent=2)

lines = json.dumps(exp, indent=2).split("\n")
out = []
for ln in lines:
    if '"pool_size":' in ln:
        out += ["<<<<<<< HEAD", ln.replace(str(new_pool), str(old_pool)), "=======", ln, ">>>>>>> change/pool-size-4471"]
    elif '"host":' in ln:
        v = ln.split(": ", 1)[1].rstrip(",").strip('"')
        out.append('    "host": “%s”,' % v)
    elif '"timeout_ms":' in ln:
        out.append(ln)
        out.append('    "timeout_ms": %d,' % (timeout // 10))   # duplicate, wrong value, jq keeps the last
    elif '"debug_endpoints":' in ln:
        out.append(ln + ",")                                    # trailing comma
    else:
        out.append(ln)
open("config.json", "w", encoding="utf-8").write("\n".join(out) + "\n")
open("TICKET.md", "w").write("""# CHG-4471, Friday evening change

Approved and applied by hand on the production host:

1. Raise `db.pool_size` from %d to %d.
2. Turn on `features.audit_log` (compliance asked for it).

Nothing else was supposed to change. The service refuses to start since
the change; `./app --check` is the same test the init script runs.
""" % (old_pool, new_pool))
PY
sha256sum config.json.last-good TICKET.md > .lm-state/sources.sum
