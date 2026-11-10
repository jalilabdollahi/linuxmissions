#!/bin/bash
# pay-01's journal, 00:00 to 03:10 (frozen clock, UTC). Finance wants the log
# of payment.service for the incident window in TICKET.txt (random per setup).
# Traps:
#  - payment-sync.service and the template instance payment@eu.service log
#    nearly the same lines; `grep payment` catches them, `-u payment.service`
#    does not.
#  - payment.service's process logs as "payment-api", and its ExecStartPre
#    migration step as "payment-migrate": -t/identifier filters miss lines.
#  - systemd's own lines about the unit (Stopping/Started/Consumed ...) carry
#    UNIT=payment.service, so -u includes them, and they belong to the answer.
# No entry lies within 3 seconds of either end of the window.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"

mkdir -p bin .lm var/log/journal etc
cp "$M/systemd/journalctl" "$M/systemd/systemctl" bin/
echo pay-01 > etc/hostname
echo "2026-11-10 03:10:00" > .lm/now

python3 - "$RANDOM$$" <<'PY'
import json, random, sys
from datetime import datetime, timezone

rnd = random.Random(sys.argv[1])
def ts(h, m, s=0):
    return datetime(2026, 11, 10, h, m, s, tzinfo=timezone.utc).timestamp()

W0 = ts(1, rnd.randint(5, 50))
W1 = W0 + 60 * rnd.randint(20, 35)
END = ts(3, 9, 40)
entries = []

def add(t, ident, msg, unit=None, pid=None, prio=6, about=None):
    e = {"__REALTIME_TIMESTAMP": str(int(t * 1e6)), "_HOSTNAME": "pay-01", "PRIORITY": str(prio),
         "SYSLOG_IDENTIFIER": ident, "MESSAGE": msg, "_PID": str(pid if pid else 1)}
    if unit:
        e["_SYSTEMD_UNIT"] = unit
    if about:                       # systemd's own message about a unit
        e["_SYSTEMD_UNIT"] = "init.scope"
        e["UNIT"] = about
    entries.append(e)

used = set()
def chid():
    while True:
        c = "ch_" + "".join(rnd.choice("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789") for _ in range(14))
        if c not in used:
            used.add(c)
            return c

pid_api, pid_sync, pid_eu = rnd.randint(1200, 1900), rnd.randint(2000, 2400), rnd.randint(2500, 2900)

def api_line(region):
    c = chid()
    amt = f"{rnd.randint(3, 900)}.{rnd.randint(0, 99):02d}"
    cur = "EUR" if region == "eu" else rnd.choice(["USD", "USD", "GBP", "EUR"])
    return rnd.choice([
        f"POST /v1/charges 201 {c} amount={amt} {cur} psp=adyen {rnd.randint(80, 400)}ms",
        f"charge {c} captured amount={amt} {cur}",
        f"POST /v1/refunds 201 re_{c[3:]} for {c} amount={amt} {cur}",
        f"GET /v1/charges/{c} 200 {rnd.randint(3, 30)}ms",
    ])

# Normal traffic for all three units over the whole span.
t = ts(0, 0, 5)
while t < END:
    r = rnd.random()
    if r < 0.45:
        add(t, "payment-api", api_line("us"), "payment.service", pid_api)
    elif r < 0.75:
        add(t, "payment", api_line("eu"), "payment@eu.service", pid_eu)
    else:
        c = chid()
        add(t, "payment-sync", rnd.choice([f"charge {c} synced to ledger",
                                           f"sync batch of {rnd.randint(5, 80)} charges done, lag {rnd.randint(1, 15)}s",
                                           f"payment.service reports {c} captured, posting to ledger"]),
            "payment-sync.service", pid_sync)
    t += rnd.randint(20, 75)

# The incident inside the window: the PSP slows down, payment.service is
# restarted by the on-call, and keeps failing for a while.
t = W0 + rnd.randint(60, 180)
for _ in range(rnd.randint(4, 7)):
    c = chid()
    add(t, "payment-api", f"PSP timeout after 10000ms for {c}, retry 1/3", "payment.service", pid_api, 4)
    t += rnd.randint(15, 50)
add(t, "payment-api", "circuit breaker OPEN for psp-adyen (5 failures in 60s)", "payment.service", pid_api, 3)
add(t + 2, "payment", "circuit breaker OPEN for psp-adyen (5 failures in 60s)", "payment@eu.service", pid_eu, 3)
add(t + 5, "payment-sync", "payment.service unreachable, pausing sync", "payment-sync.service", pid_sync, 4)
t += rnd.randint(60, 200)
add(t, "sudo", "  oncall : TTY=pts/0 ; PWD=/home/oncall ; USER=root ; COMMAND=/usr/bin/systemctl restart payment.service", None, rnd.randint(5000, 5100))
add(t + 0.2, "systemd", "Stopping payment.service - Payment API...", about="payment.service")
add(t + 0.5, "payment-api", "SIGTERM: draining 12 open requests", "payment.service", pid_api)
add(t + 3.1, "systemd", "payment.service: Deactivated successfully.", about="payment.service")
add(t + 3.1, "systemd", "Stopped payment.service - Payment API.", about="payment.service")
add(t + 3.1, "systemd", f"payment.service: Consumed {rnd.randint(1, 9)}min {rnd.randint(10, 59)}.{rnd.randint(100, 999)}s CPU time.", about="payment.service")
add(t + 3.2, "systemd", "Starting payment.service - Payment API...", about="payment.service")
pid_new = pid_api + rnd.randint(3000, 4000)
add(t + 3.5, "payment-migrate", f"schema up to date (v{rnd.randint(200, 230)}), nothing to migrate", "payment.service", pid_new - 2)
add(t + 4.0, "payment-api", "payment-api 9.3.1 listening on 127.0.0.1:8443", "payment.service", pid_new)
add(t + 4.1, "systemd", "Started payment.service - Payment API.", about="payment.service")
pid_api = pid_new
t += rnd.randint(30, 90)
for _ in range(rnd.randint(2, 4)):
    c = chid()
    add(t, "payment-api", f"PSP timeout after 10000ms for {c}, retry 2/3", "payment.service", pid_api, 4)
    t += rnd.randint(20, 80)
add(t, "payment-api", "psp-adyen healthy again, circuit breaker CLOSED", "payment.service", pid_api, 5)
add(t + 30, "payment-sync", "payment.service reachable, resuming sync", "payment-sync.service", pid_sync)
# Earlier the same night the eu instance had its own restart (not ours).
te = ts(0, rnd.randint(20, 50))
for i, m in enumerate(["Stopping payment@eu.service - Payment API (eu)...", "Stopped payment@eu.service - Payment API (eu).",
                       "Starting payment@eu.service - Payment API (eu)...", "Started payment@eu.service - Payment API (eu)."]):
    add(te + i, "systemd", m, about="payment@eu.service")

# Fix the pids of api lines after the restart, and keep both ends of the window clear.
restart = [float(e["__REALTIME_TIMESTAMP"]) / 1e6 for e in entries if e["MESSAGE"] == "Started payment.service - Payment API."][0]
for e in entries:
    if e.get("_SYSTEMD_UNIT") == "payment.service" and e["SYSLOG_IDENTIFIER"] == "payment-api" and float(e["__REALTIME_TIMESTAMP"]) / 1e6 > restart:
        e["_PID"] = str(pid_api)
entries = [e for e in entries
           if min(abs(float(e["__REALTIME_TIMESTAMP"]) / 1e6 - b) for b in (W0, W1)) > 3]
entries.sort(key=lambda e: int(e["__REALTIME_TIMESTAMP"]))
with open("var/log/journal/system.json", "w") as fh:
    for e in entries:
        fh.write(json.dumps(e) + "\n")

f = lambda x: datetime.fromtimestamp(x, timezone.utc).strftime("%H:%M")
with open("TICKET.txt", "w") as fh:
    fh.write(f"""FIN-{rnd.randint(2000, 2999)}  Payment incident 2026-11-10: log extract for the auditors

Finance needs the complete log of the payment API (unit payment.service on
pay-01) for the incident window

    2026-11-10 {f(W0)} to {f(W1)} (server time, UTC)

Messages only, please: the auditors' tool adds its own timestamps.
Do NOT include the EU instance (payment@eu.service) or the ledger sync job
(payment-sync.service); they are covered by FIN-{rnd.randint(3000, 3999)}.
""")
with open(".lm/window", "w") as fh:
    fh.write(f"2026-11-10 {f(W0)}:00\n2026-11-10 {f(W1)}:00\n")
PY
cksum var/log/journal/system.json > .lm/journal.sum
