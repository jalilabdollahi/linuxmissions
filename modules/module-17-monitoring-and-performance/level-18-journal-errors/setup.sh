#!/bin/bash
# journal.json: one hour of journal entries in `journalctl -o json` shape, random start
# time. Decoys: a minute with exactly 10 errors, a minute with many warnings (PRIORITY 4)
# but few errors, errors of priority 2 and 1 inside the spike, kernel errors without
# _SYSTEMD_UNIT, and a unit that is the biggest error source over the whole hour but
# not in the spike minute.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

python3 - <<'LMEND'
import json, random, collections

units = ["billing.service", "auth.service", "api.service", "worker.service", "nginx.service", "cache.service"]
while True:
    start = 1762000000 + random.randint(0, 6 * 86400)
    start -= start % 60
    S = random.randint(30, 44)                   # spike minute index
    k1 = random.randint(8, 14)                   # exactly 10 errors
    k2 = random.randint(18, 24)                  # warnings storm
    spike_unit = random.choice(units[:4])
    late_unit = random.choice([u for u in units if u != spike_unit and u != "cache.service"])
    ev = []   # (minute, priority, unit or None, message)
    def add(m, pr, unit, msg):
        ev.append((m, pr, unit, msg))
    for m in range(60):
        n_err = random.randint(0, 4)
        if m == k1: n_err = 10
        if m == k2: n_err = 5
        if m == S: n_err = random.randint(12, 16)
        if m > S: n_err = random.randint(12, 18)
        for _ in range(n_err):
            if m == k1:
                unit = "cache.service"
            elif m == S:
                unit = spike_unit if random.random() < 0.6 else random.choice(units)
            elif m > S:
                unit = late_unit if random.random() < 0.75 else random.choice(units)
            else:
                unit = "cache.service" if random.random() < 0.35 else random.choice(units)
            pr = random.choice(["3", "3", "3", "2"]) if m == S else random.choice(["3", "3", "3", "3", "2"])
            add(m, pr, unit, random.choice([
                "connection to upstream failed: timeout after 30s",
                "request \"GET /v1/items\" failed with status 500",
                "database error: deadlock detected, retrying",
                "failed to write cache entry: no space left on device",
                "unhandled exception in handler: KeyError 'user'",
            ]))
        if m == S:                               # kernel errors: no unit
            for _ in range(2):
                add(m, "3", None, "EXT4-fs warning: ext4_dx_add_entry: directory index full")
        n_warn = random.randint(2, 7) + (random.randint(9, 12) if m == k2 else 0)
        for _ in range(n_warn):
            add(m, "4", random.choice(units), random.choice(["slow response: 2.4s", "retry 2/5 for upstream", "queue length above soft limit"]))
        for _ in range(random.randint(12, 26)):
            add(m, random.choice(["6", "6", "6", "5", "7"]), random.choice(units), random.choice(["request served in 12ms", "session refreshed", "heartbeat ok", "config reloaded (generation 4)", "cron: job finished"]))
    # S must be the first minute with > 10 errors, and the spike minute's top unit must be unique
    errs = collections.Counter()
    per_min = collections.Counter()
    spike_units = collections.Counter()
    total_units = collections.Counter()
    for m, pr, unit, msg in ev:
        if int(pr) <= 3:
            per_min[m] += 1
            if unit: total_units[unit] += 1
            if m == S and unit: spike_units[unit] += 1
    first = min(m for m in range(60) if per_min[m] > 10)
    top = spike_units.most_common(2)
    if first != S or (len(top) > 1 and top[0][1] == top[1][1]) or top[0][0] == total_units.most_common(1)[0][0]:
        continue
    pr3_only = sum(1 for m, pr, u, _ in ev if m == S and pr == "3")
    if pr3_only > 10:     # a PRIORITY=="3"-only count must miss the spike minute
        continue
    break

rows = []
for m, pr, unit, msg in ev:
    us = (start + m * 60 + random.randint(0, 59)) * 1000000 + random.randint(0, 999999)
    rows.append((us, pr, unit, msg))
rows.sort()
with open("journal.json", "w") as f:
    for i, (us, pr, unit, msg) in enumerate(rows):
        o = {"__CURSOR": f"s=4c1f;i={i:x};b=9a2e;m={us:x};t={us:x};x=77aa",
             "__REALTIME_TIMESTAMP": str(us),
             "__MONOTONIC_TIMESTAMP": str(us - 1761000000000000),
             "_BOOT_ID": "9a2e5f4c0d1b4f7e8a3c2b1d6e5f4a30",
             "_HOSTNAME": "app01",
             "PRIORITY": pr}
        if unit:
            o["_SYSTEMD_UNIT"] = unit
            o["SYSLOG_IDENTIFIER"] = unit.split(".")[0]
            o["_PID"] = str(1000 + (hash(unit) % 5000))
        else:
            o["SYSLOG_IDENTIFIER"] = "kernel"
            o["_TRANSPORT"] = "kernel"
        if i % 997 == 0:
            o["MESSAGE"] = list(msg.encode())     # journald exports non-text messages as byte arrays
        else:
            o["MESSAGE"] = msg
        f.write(json.dumps(o, separators=(",", ":")) + "\n")
t = start + S * 60
import time
with open(".lm-state/answer", "w") as f:
    f.write(time.strftime("%H:%M", time.gmtime(t)) + " " + top[0][0] + "\n")
LMEND
[ -s .lm-state/answer ] || { echo "data generation failed" >&2; exit 1; }
