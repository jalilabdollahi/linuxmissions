#!/bin/bash
# 12 services, one template, per-service env files (CRLF, `export ` prefixes,
# passwords with $). The overnight push used plain envsubst on sourced env:
# passwords cut at the first $ and $RUNTIME_DIR emptied. live/ has the
# running configs: a few with real manual changes, all with noise (comments).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p env rendered live .lm-state
python3 - <<'PY'
import hashlib, json, os, random, re
R = random.Random()
AL = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
svcs = sorted(R.sample(["api", "auth", "billing", "cart", "catalog", "checkout", "cms", "mailer", "orders", "search", "shipping", "stock", "users", "web", "worker", "reports"], 12))
tpl = """# managed by config management - do not edit by hand
[service]
name = ${SVC_NAME}
listen = 0.0.0.0:${LISTEN_PORT}
workdir = $RUNTIME_DIR/${SVC_NAME}

[db]
host = ${DB_HOST}
user = ${DB_USER}
password = ${DB_PASS}

[limits]
max_conn = ${MAX_CONN}
health = http://127.0.0.1:${LISTEN_PORT}/health
"""
open("template.conf", "w").write(tpl)
names = ["SVC_NAME", "LISTEN_PORT", "DB_HOST", "DB_USER", "DB_PASS", "MAX_CONN"]
def pw():
    p = "".join(R.choice(AL) for _ in range(R.randint(6, 9)))
    k = R.choice(["head", "mid", "var", "digit"])
    i = R.randint(1, len(p) - 1)
    ins = {"head": "$", "mid": "$$", "var": "$HOME", "digit": "$1"}[k]
    return p[:i] + ins + p[i:]
vals = {}
for i, s in enumerate(svcs):
    vals[s] = {"SVC_NAME": s, "LISTEN_PORT": str(9000 + i * 7 + R.randint(0, 6)), "DB_HOST": "db-%s.internal" % R.choice(["a", "b", "c"]), "DB_USER": "svc_" + s,
               "DB_PASS": pw(), "MAX_CONN": str(R.choice([50, 100, 200, 400]))}
    lines = ["%s=%s" % (k, vals[s][k]) for k in names] + ["COMMENT_OWNER=team-%d" % R.randint(1, 5)]
    R.shuffle(lines)
    exp = R.random() < 0.5
    lines = [("export " if exp and R.random() < 0.8 else "") + l for l in lines]
    nl = "\r\n" if R.random() < 0.85 else "\n"
    open("env/%s.env" % s, "w", newline="").write(nl.join(lines) + nl)
def render(v):
    return re.sub(r"\$\{(%s)\}" % "|".join(names), lambda m: v[m.group(1)], tpl)
def broken(v):
    b = dict(v); b["DB_PASS"] = re.split(r"\$", v["DB_PASS"])[0]
    return re.sub(r"\$RUNTIME_DIR", "", render(b))
drift = sorted(R.sample(svcs, R.randint(3, 4)))
for s in svcs:
    open("rendered/%s.conf" % s, "w").write(broken(vals[s]))
    good = render(vals[s]).split("\n")
    live = ["# last pushed 2026-11-%02dT0%d:%02d" % (R.randint(1, 9), R.randint(1, 6), R.randint(0, 59))] + good
    if s in drift:
        kind = R.choice(["value", "extra", "removed"])
        if kind == "value":
            live = [l.replace("max_conn = %s" % vals[s]["MAX_CONN"], "max_conn = 1000") for l in live]
        elif kind == "extra":
            live.insert(len(live) - 1, "slow_query_log = on")
        else:
            live = [l for l in live if not l.startswith("health =")]
    if R.random() < 0.5 and s not in drift:
        live.insert(5, "# TODO ask the db team about the pool")
    if R.random() < 0.5 and s not in drift:
        live.insert(3, "")
    open("live/%s.conf" % s, "w").write("\n".join(live))
exp = {s: render(vals[s]) for s in svcs}
json.dump({"services": svcs, "expected": exp, "drift": drift}, open(".lm-state/truth.json", "w"))
man = ["%s  %s" % (hashlib.sha256(open(p, "rb").read()).hexdigest(), p) for p in ["template.conf"] + ["live/%s.conf" % s for s in svcs]]
open(".lm-state/sources.sum", "w").write("\n".join(man) + "\n")
open("OVERNIGHT.md", "w").write("""# Config push gone wrong

Overnight, config management rendered `template.conf` for all 12 services
into `rendered/<service>.conf` using the values in `env/<service>.env`. The
result is broken (empty or truncated passwords, empty paths), and the services
restart-loop on it.

Required:
1. Every `rendered/<service>.conf` must be `template.conf` with exactly the
   `${NAME}` placeholders filled from that service's env file (values are raw
   text: a `$` in a password is a `$`; env files come from another OS and
   may have `export ` in front and Windows line endings). A bare `$RUNTIME_DIR`
   in the template is not a placeholder: it is resolved by the service at
   run time and must stay as written.
2. `live/<service>.conf` is what is actually running now. Before anything is
   overwritten, list in `drift.txt` (one service per line, sorted) the services
   whose live config has manual changes worth keeping: any difference from the
   correct rendering in a line that is not a comment or blank. Comment
   and blank-line differences are noise.
Leave `template.conf` and `live/` alone.
""")
PY
