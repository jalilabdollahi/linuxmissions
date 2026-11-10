#!/bin/bash
# $1 = sandbox path
# Reads etc/resolv.conf for the nameservers, then runs the lab resolver (a
# pristine copy) for real and watches the DNS servers' query logs:
#   api             -> exactly one query, api.<svc>.corp.example., answered
#   db.corp.example -> exactly one query, db.corp.example.
#   short names from every search domain still resolve
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import os, subprocess, sys, time

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

ns_map = dict(l.split() for l in open(".net/nameservers") if l.strip())
dead, live = list(ns_map)
svc = open(".net/svcdomain").read().strip()
try:
    lines = open("etc/resolv.conf").read().splitlines()
except FileNotFoundError:
    fail("etc/resolv.conf is missing")
servers = [l.split()[1] for l in lines if l.split()[:1] == ["nameserver"] and len(l.split()) > 1]
if not servers:
    fail("etc/resolv.conf has no nameserver line left")
if dead in servers:
    fail(f"{dead} is still listed; it was switched off and every query to it waits for a timeout")
other = [s for s in servers if s != live]
if other:
    fail(f"nameserver {other[0]} is not one of our DNS servers (the current one is {live})")

logs = {ip: f"logs/dns-{ip}.log" for ip in ns_map}
def size(path):
    try:
        return len(open(path).read().splitlines())
    except FileNotFoundError:
        return 0

def run(name):
    """Run the resolver; return (found, [new query log lines])."""
    before = size(logs[live])
    try:
        rc = subprocess.run(["python3", ".net/getent.orig", "hosts", name], capture_output=True, timeout=20).returncode
    except subprocess.TimeoutExpired:
        fail(f"looking up {name} took more than 20 s")
    new = []
    for _ in range(10):
        new = open(logs[live]).read().splitlines()[before:]
        if new or rc != 0:
            break
        time.sleep(0.1)
    time.sleep(0.2)
    return rc == 0, [l.split()[3] for l in open(logs[live]).read().splitlines()[before:]]

ok, q = run("api")
want = f"api.{svc}.corp.example."
if not ok:
    fail("getent hosts api finds nothing; is the domain where api lives still in the search list?")
if q[:1] != [want] or len(q) != 1:
    fail(f"looking up api sent {len(q)} queries ({', '.join(q[:4])}{'...' if len(q) > 4 else ''}); the first one should already be {want}")
ok, q = run("db.corp.example")
if not ok:
    fail("getent hosts db.corp.example finds nothing")
if q[:1] != ["db.corp.example."]:
    fail(f"db.corp.example is first asked as {q[0]}; a name with dots should be tried as it is first (look at ndots)")
if len(q) != 1:
    fail(f"looking up db.corp.example sent {len(q)} queries, expected one")
zone = open(".net/corp.zone").read()
for short, dom in (("wiki", "corp.example"), ("grafana", "lab.corp.example"), ("queue", f"{svc}.corp.example")):
    ok, _ = run(short)
    if not ok:
        fail(f"{short} ({short}.{dom}) no longer resolves; keep all three search domains")
print(f"✅ api is answered by the first query, full names are tried as-is, and only {live} is used")
PY
