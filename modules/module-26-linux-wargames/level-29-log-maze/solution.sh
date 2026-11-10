#!/bin/bash
python3 - <<'PY'
import json, re
from datetime import datetime, timedelta, timezone
ev = []   # (utc, service, level, rid, line)
def U(s, fmt, off=0): return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc) - timedelta(minutes=off)
for l in open("logs/gateway.log"):
    m = re.match(r"(\S+Z) gateway (\w+) request_id=(\S+)", l)
    if m: ev.append((U(m[1], "%Y-%m-%dT%H:%M:%S.%fZ"), "gateway", m[2], m[3], l.rstrip("\n")))
for l in open("logs/checkout.log"):
    m = re.match(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d,\d{3}) \+0330 checkout \[(\w+)\] X-Request-ID=(\S+)", l)
    if m: ev.append((U(m[1], "%Y-%m-%d %H:%M:%S,%f", 210), "checkout", m[2], m[3], l.rstrip("\n")))
for l in open("logs/payments.log"):
    d = json.loads(l); ev.append((datetime.fromtimestamp(d["ts"] / 1000, timezone.utc), "payments", d["level"], d["trace"], l.rstrip("\n")))
for l in open("logs/inventory.log"):
    m = re.match(r"(\d\d/Nov/2026:\d\d:\d\d:\d\d\.\d{3}) \+0000 (\w+) \[req=(\S+)\]", l)
    if m: ev.append((U(m[1], "%d/%b/%Y:%H:%M:%S.%f"), "inventory", m[2], m[3], l.rstrip("\n")))
for l in open("logs/notifier.log"):
    m = re.match(r"(\S+)\+01:00 notifier (\w+) rid=(\S+)", l)
    if m: ev.append((U(m[1], "%Y-%m-%dT%H:%M:%S", 60), "notifier", m[2], m[3], l.rstrip("\n")))
failing = {e[3] for e in ev if e[1] == "gateway" and "status=5" in e[4]}
first = min((e for e in ev if e[2] == "ERROR" and e[3] in failing), key=lambda e: e[0])
open("rootcause.txt", "w").write(first[1] + "\n" + first[4] + "\n")
tid = re.search(r"request_id=(\S+)", open("TICKET.txt").read())[1]
with open("timeline.tsv", "w") as f:
    for t, s, lv, r, _ in sorted((e for e in ev if e[3] == tid), key=lambda e: e[0]):
        f.write("%s\t%s\t%s\n" % (t.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (t.microsecond // 1000), s, lv))
PY
