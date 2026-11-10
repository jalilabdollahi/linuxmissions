#!/bin/bash
# /var/log/syslog of app-02 (classic rsyslog format) from midnight to 03:09.
# The question: which three programs logged the most messages between 02:00:00
# and 02:59:59? The counts are planned per setup so that every shortcut gives a
# different top 3:
#  - one top program mostly logs "message repeated N times: [ ... ]" lines
#    (rsyslog's duplicate reduction): each stands for N messages;
#  - one top program logs both as "orders-api[2231]:" and "orders-api:";
#  - filebeat floods the log before and after the hour, not in it;
#  - lines at 01:59:59 and 03:00:00 sit right outside the window.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p var/log .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
from collections import Counter

seed = sys.argv[1]
HOST = "app-02"

def build(rnd):
    out = []                                  # (seconds since midnight, "prog[pid]" or "prog", message)
    def at(h0, h1):
        return rnd.uniform(h0 * 3600, h1 * 3600 - 1)
    hexid = lambda n: "".join(rnd.choice("0123456789abcdef") for _ in range(n))
    pod = lambda: f"orders-worker-7d9f8c6b5-{''.join(rnd.choice('bcdfghjklmnpqrstvwxz2456789') for _ in range(5))}"

    msgs = {
        "kubelet": lambda t: f'E1110 {fmt(t)}.{rnd.randint(0, 999999):06d}    1544 pod_workers.go:1298] "Error syncing pod, skipping" err="failed to \\"StartContainer\\" for \\"worker\\" with CrashLoopBackOff: \\"back-off 5m0s restarting failed container=worker pod={pod()}_prod\\"" pod="prod/{pod()}"',
        "containerd": lambda t: rnd.choice([
            f'time="2026-11-10T{fmt(t)}.{rnd.randint(0, 10**9 - 1):09d}Z" level=info msg="StartContainer for \\"{hexid(64)}\\" returns successfully"',
            f'time="2026-11-10T{fmt(t)}.{rnd.randint(0, 10**9 - 1):09d}Z" level=info msg="shim disconnected" id={hexid(64)} namespace=k8s.io',
            f'time="2026-11-10T{fmt(t)}.{rnd.randint(0, 10**9 - 1):09d}Z" level=warning msg="cleaning up after shim disconnected" id={hexid(64)} namespace=k8s.io']),
        "orders-api": lambda t: rnd.choice([
            f"WARN retrying upstream inventory-svc: 503 Service Unavailable (attempt {rnd.randint(1, 5)}/5)",
            f"ERROR order {rnd.randint(900000, 999999)} failed: inventory-svc timeout after 2000ms",
            f"INFO GET /api/orders/{rnd.randint(900000, 999999)} 200 {rnd.randint(5, 90)}ms"]),
        "filebeat": lambda t: f'{{"log.level":"error","@timestamp":"2026-11-10T{fmt(t)}.{rnd.randint(0, 999):03d}Z","log.logger":"publisher_pipeline_output","log.origin":{{"function":"github.com/elastic/beats/v7/libbeat/publisher/pipeline.(*netClientWorker).publishEvents","file.name":"pipeline/client_worker.go","file.line":174}},"message":"failed to publish events: temporary bulk send failure","service.name":"filebeat","ecs.version":"1.6.0"}}',
        "dockerd": lambda t: f'time="2026-11-10T{fmt(t)}.{rnd.randint(0, 10**9 - 1):09d}Z" level=warning msg="Health check for container {hexid(64)} error: context deadline exceeded"',
        "systemd": lambda t: rnd.choice([f"Started session-{rnd.randint(100, 999)}.scope - Session {rnd.randint(100, 999)} of User deploy.",
                                         "run-containerd-runc-k8s.io-" + hexid(64) + "-runc." + "".join(rnd.choice("ABCDEFGHabcdefgh") for _ in range(6)) + ".mount: Deactivated successfully."]),
        "CRON": lambda t: rnd.choice(["(root) CMD (command -v debian-sa1 > /dev/null && debian-sa1 1 1)", "(root) CMD (   test -x /etc/cron.daily/popularity-contest && /etc/cron.daily/popularity-contest --crond)"]),
        "kernel": lambda t: f"[UFW BLOCK] IN=ens3 OUT= MAC=52:54:00:4a:1b:2c:fe:54:00:3d:9e:01:08:00 SRC={rnd.randint(1, 223)}.{rnd.randint(0, 255)}.{rnd.randint(0, 255)}.{rnd.randint(1, 254)} DST=10.0.1.12 LEN=40 TOS=0x00 PREC=0x00 TTL=241 ID={rnd.randint(1, 65535)} PROTO=TCP SPT={rnd.randint(1024, 65535)} DPT={rnd.choice([22, 23, 445, 3389, 8080])} WINDOW=1024 RES=0x00 SYN URGP=0",
        "snapd": lambda t: 'storehelpers.go:769: cannot refresh: snap has no updates available: "core22", "lxd", "snapd"',
    }
    pids = {"kubelet": 1544, "containerd": 901, "orders-api": 2231, "filebeat": 1210, "dockerd": 880, "systemd": 1, "snapd": 702}
    def tag(p):
        if p == "kernel":
            return "kernel"
        if p == "CRON":
            return f"CRON[{rnd.randint(30000, 60000)}]"
        return f"{p}[{pids[p]}]"
    def emit(p, n, h0, h1, nopid=0.0):
        for _ in range(n):
            t = at(h0, h1)
            out.append((t, (p + ":") if rnd.random() < nopid else tag(p) + ":", msgs[p](t)))

    # true counts inside 02:00-02:59 for the three top programs
    c3 = rnd.randint(1200, 1700)
    c2 = c3 + rnd.randint(150, 450)
    c1 = c2 + rnd.randint(150, 450)
    top = ["kubelet", "orders-api", "containerd"]
    rnd.shuffle(top)
    want = dict(zip(top, (c1, c2, c3)))

    # kubelet: some plain lines, most as "message repeated N times"
    plain = rnd.randint(90, 160)
    emit("kubelet", plain, 2, 3)
    left = want["kubelet"] - plain
    while left > 0:
        n = min(left, rnd.randint(60, 480))
        if left - n and left - n < 2:
            n = left
        t = at(2, 3)
        out.append((t, tag("kubelet") + ":", f"message repeated {n} times: [ " + msgs["kubelet"](t) + "]"))
        left -= n
    # orders-api: logs both with and without [pid] (logger vs. the app itself)
    emit("orders-api", want["orders-api"], 2, 3, nopid=rnd.uniform(0.42, 0.58))
    emit("containerd", want["containerd"], 2, 3)
    # the rest of the hour
    emit("filebeat", c3 - rnd.randint(40, 140), 2, 3)
    emit("dockerd", rnd.randint(500, 900), 2, 3)
    for p, lo, hi in (("systemd", 150, 400), ("CRON", 30, 60), ("kernel", 200, 450), ("snapd", 5, 20)):
        emit(p, rnd.randint(lo, hi), 2, 3)
    # outside the hour: filebeat floods, the others at a normal rate
    emit("filebeat", rnd.randint(3500, 5000), 0, 2)
    emit("filebeat", rnd.randint(500, 900), 3, 3 + 9 / 60)
    for p in ("kubelet", "orders-api", "containerd", "dockerd", "systemd", "kernel"):
        emit(p, rnd.randint(150, 600), 0, 2)
        emit(p, rnd.randint(20, 80), 3, 3 + 9 / 60)
    emit("CRON", 60, 0, 2)
    # right at the edges of the window
    for p in ("filebeat", "dockerd", "kernel"):
        for t in (2 * 3600 - 1, 3 * 3600):
            for _ in range(rnd.randint(30, 80)):
                out.append((t + 0.5, tag(p) + ":", msgs[p](t)))
    out.sort(key=lambda x: x[0])
    return out

def fmt(t):
    t = int(t)
    return f"{t // 3600:02d}:{t // 60 % 60:02d}:{t % 60:02d}"

def rankings(lines):
    import re
    true, split, nocount, all_ = Counter(), Counter(), Counter(), Counter()
    for t, tg, m in lines:
        n = int(re.match(r"message repeated (\d+) times", m)[1]) if m.startswith("message repeated") else 1
        prog = tg[:-1].split("[")[0]
        all_[prog] += n
        if 7200 <= int(t) < 10800:
            true[prog] += n
            split[re.sub(r"\[\d+\]:$", "", tg)] += n     # "orders-api:" stays apart from "orders-api"
            nocount[prog] += 1
    top3 = lambda c: sorted(c.items(), key=lambda kv: (-kv[1], kv[0]))[:3]
    return top3(true), [top3(c) for c in (split, nocount, all_)], sorted(true.values(), reverse=True)

rnd = random.Random(seed)
while True:
    lines = build(rnd)
    t3, naive, ranked = rankings(lines)
    if ranked[2] - ranked[3] >= 30 and len(set(ranked[:4])) == 4 and all(n != t3 for n in naive):
        break

with open("var/log/syslog", "w") as fh:
    for t, tg, m in lines:
        fh.write(f"Nov 10 {fmt(t)} {HOST} {tg} {m}\n")
PY
cksum var/log/syslog > .lm-state/syslog.sum
