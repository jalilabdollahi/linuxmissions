#!/bin/bash
# Restart storm: queue-consumer exits non-zero whenever the broker blips
# (heartbeat timeout). The unit has Restart=always and no RestartSec, so it
# burns the default start limit (5 starts in 10 s) in half a second and
# systemd gives up: "Start request repeated too quickly". TICKET.md asks for
# new values (random per setup): Restart only on failure (the operator's
# `drain` exits 0 on purpose and must stay stopped), RestartSec, and
# StartLimitBurst / StartLimitIntervalSec large enough to ride out a blip of
# BURST-1 failures in a row. The consumer reads its next "step" from
# var/lib/queue/broker-script (blip or ok), which is how the validator
# replays the crash pattern. Mock systemctl/journalctl in bin/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin .lm/systemd/units .lm-state var/log/journal var/lib/queue etc/systemd/system/multi-user.target.wants opt/queue/bin
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo q-02 > etc/hostname
echo "2026-11-10 08:30:00" > .lm/now

python3 - "$RANDOM$$" <<'PY'
import json, random, sys, uuid
from datetime import datetime, timezone

R = random.Random(int(sys.argv[1]))
HOST = "q-02"
BOOT = uuid.UUID(int=R.getrandbits(128)).hex
rsec = R.choice([2, 3, 5])
burst = R.choice([6, 8, 10])
interval = R.choice([60, 120])
blips = burst - 1
fmt = {30: "30s", 60: "1min", 120: "2min"}
with open(".lm-state/want", "w") as f:
    f.write("RESTARTSEC=%d\nRESTARTUSEC=%ds\nBURST=%d\nINTERVALSEC=%d\nINTERVALUSEC=%s\nBLIPS=%d\n"
            % (rsec, rsec, burst, interval, fmt[interval], blips))
with open("var/lib/queue/broker-script", "w") as f:
    f.write("blip\n" * blips + "ok\n")
open("var/lib/queue/pos", "w").write("%d\n" % (blips + 1))

entries = []
def ts(s):
    return int(datetime.strptime(s, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).timestamp() * 1e6)
def E(t, ident, msg, prio=6, pid=1, unit="queue-consumer.service", us=0, comm=False):
    e = {"__REALTIME_TIMESTAMP": str(ts(t) + us), "_BOOT_ID": BOOT, "_HOSTNAME": HOST, "PRIORITY": str(prio),
         "SYSLOG_IDENTIFIER": ident, "MESSAGE": msg, "_PID": str(pid)}
    if ident == "systemd":
        e["UNIT"] = unit
    else:
        e["_SYSTEMD_UNIT"] = unit
    entries.append(e)

def start(t, us=0):
    E(t, "systemd", "Started queue-consumer.service - Queue consumer (jobs from the broker).", unit="queue-consumer.service", us=us)

# Yesterday evening: an operator drained the consumer for maintenance. It
# exited 0 on purpose and systemd brought it straight back (Restart=always).
pid = R.randint(3000, 3999)
start("2026-11-09 17:02:11")
E("2026-11-09 17:02:12", "queue-consumer", "connected to broker, consuming", pid=pid)
E("2026-11-09 21:58:40", "sudo", "  ops-dina : TTY=pts/1 ; PWD=/home/ops-dina ; USER=root ; COMMAND=/usr/bin/touch /var/lib/queue/drain", 5, pid=R.randint(9000, 9999), unit="session-4.scope")
E("2026-11-09 21:58:40", "queue-consumer", "drain requested: finishing in-flight jobs, exiting", pid=pid)
E("2026-11-09 21:58:41", "systemd", "queue-consumer.service: Deactivated successfully.", unit="queue-consumer.service")
E("2026-11-09 21:58:41", "systemd", "queue-consumer.service: Scheduled restart job, restart counter is at 1.", unit="queue-consumer.service", us=100000)
start("2026-11-09 21:58:41", us=200000)
E("2026-11-09 21:58:41", "queue-consumer", "connected to broker, consuming", pid=pid + 7, us=300000)
E("2026-11-09 21:59:30", "sudo", "  ops-dina : TTY=pts/1 ; PWD=/home/ops-dina ; USER=root ; COMMAND=/usr/bin/systemctl stop queue-consumer.service", 5, pid=R.randint(9000, 9999), unit="session-4.scope")
E("2026-11-09 21:59:31", "systemd", "Stopping queue-consumer.service - Queue consumer (jobs from the broker)...", unit="queue-consumer.service")
E("2026-11-09 21:59:31", "systemd", "Stopped queue-consumer.service - Queue consumer (jobs from the broker).", unit="queue-consumer.service", us=50000)

# This morning: the broker blipped.
T = "2026-11-10 03:41"
E("2026-11-10 03:38:20", "systemd", "Started queue-consumer.service - Queue consumer (jobs from the broker).", unit="queue-consumer.service")
E("2026-11-10 03:38:20", "queue-consumer", "connected to broker, consuming", pid=pid + 100, us=300000)
E("2026-11-10 03:41:07", "broker", "mq-01: node restarting for the monthly kernel update (blip of a few seconds)", 4, pid=1, unit="broker-watch.service")
n = 0
t0 = ts("2026-11-10 03:41:07") + 300000
cpid = pid + 200
for i in range(1, 7):
    t = t0 + (i - 1) * 105000
    base = {"_BOOT_ID": BOOT, "_HOSTNAME": HOST}
    def ev(off, ident, msg, prio, p, unit):
        e = dict(base); e.update({"__REALTIME_TIMESTAMP": str(t + off), "PRIORITY": str(prio), "SYSLOG_IDENTIFIER": ident,
                                  "MESSAGE": msg, "_PID": str(p)})
        if ident == "systemd": e["UNIT"] = unit
        else: e["_SYSTEMD_UNIT"] = unit
        entries.append(e)
    cpid += 1
    ev(0, "queue-consumer", "broker connection lost: heartbeat timeout after 3000 ms", 3, cpid, "queue-consumer.service")
    ev(2000, "systemd", "queue-consumer.service: Main process exited, code=exited, status=1/FAILURE", 5, 1, "queue-consumer.service")
    ev(3000, "systemd", "queue-consumer.service: Failed with result 'exit-code'.", 4, 1, "queue-consumer.service")
    if i < 6:
        ev(103000, "systemd", "queue-consumer.service: Scheduled restart job, restart counter is at %d." % i, 6, 1, "queue-consumer.service")
        ev(104000, "systemd", "Started queue-consumer.service - Queue consumer (jobs from the broker).", 6, 1, "queue-consumer.service")
    else:
        ev(104000, "systemd", "queue-consumer.service: Start request repeated too quickly.", 3, 1, "queue-consumer.service")
        ev(105000, "systemd", "queue-consumer.service: Failed with result 'start-limit-hit'.", 3, 1, "queue-consumer.service")
        ev(106000, "systemd", "Failed to start queue-consumer.service - Queue consumer (jobs from the broker).", 3, 1, "queue-consumer.service")
E("2026-11-10 03:41:30", "broker", "mq-01: back online, accepting connections", 6, pid=1, unit="broker-watch.service")
E("2026-11-10 07:55:12", "pagerduty-agent", "alert: queue depth 48213 and growing (queue-consumer inactive)", 4, pid=R.randint(900, 990), unit="pd-agent.service")

for h in range(0, 9):
    for m in (10, 40):
        E("2026-11-10 %02d:%02d:01" % (h, m), "CRON", "(root) CMD (command -v debian-sa1 > /dev/null && debian-sa1 1 1)", pid=R.randint(20000, 29999), unit="cron.service")
entries.sort(key=lambda e: int(e["__REALTIME_TIMESTAMP"]))
with open("var/log/journal/system.json", "w") as f:
    for e in entries:
        f.write(json.dumps(e) + "\n")
PY

cat > opt/queue/bin/queue-consumer <<'LMEND2'
#!/bin/bash
# queue-consumer (stand-in): takes jobs from the broker.
# Each start reads its next step from var/lib/queue/broker-script:
#   blip -> the broker is unreachable: log it and exit 1
#   ok   -> connected, work until /var/lib/queue/drain appears (then exit 0)
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
Q="$ROOT/var/lib/queue"
n=$(cat "$Q/pos" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$Q/pos"
step=$(sed -n "${n}p" "$Q/broker-script")
if [ "$step" = blip ]; then
  echo "broker connection lost: heartbeat timeout after 3000 ms" >&2
  exit 1
fi
echo "connected to broker, consuming"
while :; do
  if [ -e "$Q/drain" ]; then
    rm -f "$Q/drain"
    echo "drain requested: finishing in-flight jobs, exiting"
    exit 0
  fi
  sleep 0.2
done
LMEND2
chmod +x opt/queue/bin/queue-consumer
sha256sum opt/queue/bin/queue-consumer var/lib/queue/broker-script > .lm-state/sha

cat > etc/systemd/system/queue-consumer.service <<'LMEND2'
[Unit]
Description=Queue consumer (jobs from the broker)
After=network.target

[Service]
Type=simple
ExecStart=/opt/queue/bin/queue-consumer
Restart=always

[Install]
WantedBy=multi-user.target
LMEND2
ln -s /etc/systemd/system/queue-consumer.service etc/systemd/system/multi-user.target.wants/queue-consumer.service
cp etc/systemd/system/queue-consumer.service .lm-state/unit.orig

. .lm-state/want
cat > TICKET.md <<LMEND2
# INC-4471: queue-consumer stays dead after a broker blip

This morning at 03:41 the broker node restarted for a few seconds.
queue-consumer lost its connection, exited with an error and was restarted
immediately, over and over, until systemd gave up. Nobody noticed until the
queue depth alert at 07:55.

Required behaviour for queue-consumer.service:

- Restart it after a failure (non-zero exit, crash, kill), and ONLY then.
  The operators' maintenance command "drain" makes it exit 0 on purpose; after
  that the service must stay stopped (last night's surprise restart was a bug).
- Wait ${RESTARTSEC}s between restart attempts, to give the broker time to come back.
- A blip is up to $BLIPS failures in a row. systemd must allow ${BURST} starts
  within ${INTERVALSEC} seconds before it gives up (StartLimitBurst=${BURST},
  StartLimitIntervalSec=${INTERVALSEC}).
- Keep the service enabled and do not touch /opt/queue/bin/queue-consumer.

Then get it running again.
LMEND2

cat > .lm/systemd/units/queue-consumer.service.state <<'LMEND2'
ActiveState=failed
SubState=failed
Result=start-limit-hit
ExecMainPID=3205
ExecMainCode=exited
ExecMainStatus=1
MainPID=0
NRestarts=5
StateChangeTimestamp=2026-11-10 03:41:08
InactiveEnterTimestamp=2026-11-10 03:41:08
LMEND2
bin/systemctl daemon-reload
