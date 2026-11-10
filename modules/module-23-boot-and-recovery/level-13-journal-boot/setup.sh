#!/bin/bash
# Which Boot Died? journal.json: four boots, merged from two exports (each in time order,
# concatenated, so the file is not). One boot ends without systemd-shutdown's final
# "Powering off."/"Rebooting." message; it is split across both exports. Decoys: errors in
# the clean boots, warnings (PRIORITY "4") and "error" words at PRIORITY "6" in the crashed one.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p .lm-state
python3 - <<'PYEOF'
import json, random, time
R = random.SystemRandom()
host = R.choice(["web-03", "db-02", "app-07", "edge-01", "queue-04"])
now = int(time.time())
nb = 4
crash = R.randrange(0, 3)            # never the last boot, so "the newest" is not the answer
ids = ["%032x" % R.getrandbits(128) for _ in range(nb)]
t = now - R.randrange(20, 40) * 86400
bounds = []
for i in range(nb):
    start = t + R.randrange(600, 40000)
    end = start + R.randrange(3 * 3600, 20 * 3600)
    bounds.append((start, end))
    t = end + R.randrange(60, 900)

def unit():
    return R.choice(["nginx", "postgresql@16-main", "redis-server", "cron", "ssh", "rsyslog",
                     "unattended-upgrades", "prometheus-node-exporter", "chrony", "fail2ban"])
def pid(): return R.randrange(900, 31000)
def proc(): return R.choice(["java", "python3", "postgres", "node", "rsync", "clamscan"])
def dev(): return R.choice(["sda", "sdb", "nvme0n1", "vda"])

def errors_crash():
    u = unit()
    pool = [
        ("kernel", 3, lambda: "EXT4-fs error (device %s2): ext4_find_entry:1455: inode #%d: comm %s: reading directory lblock 0" % (dev(), R.randrange(1000, 900000), proc())),
        ("kernel", 2, lambda: "Out of memory: Killed process %d (%s) total-vm:%dkB, anon-rss:%dkB" % (pid(), proc(), R.randrange(2000000, 9000000), R.randrange(1000000, 2000000))),
        ("kernel", 3, lambda: "blk_update_request: I/O error, dev %s, sector %d op 0x0:(READ) flags 0x80700 phys_seg 4 prio class 2" % (dev(), R.randrange(1000000, 900000000))),
        ("systemd", 3, lambda: "%s.service: Failed with result 'exit-code'." % u),
        ("kernel", 2, lambda: "watchdog: BUG: soft lockup - CPU#%d stuck for %ds! [kworker/%d:1:%d]" % (R.randrange(0, 8), R.randrange(22, 60), R.randrange(0, 8), pid())),
        ("kernel", 1, lambda: "INFO: task %s:%d blocked for more than 120 seconds." % (proc(), pid())),
        ("kernel", 0, lambda: "Kernel panic - not syncing: hung_task: blocked tasks"),
    ]
    return pool
def errors_clean():
    return [
        ("systemd", 3, lambda: "%s.service: Main process exited, code=exited, status=1/FAILURE" % unit()),
        ("kernel", 3, lambda: "nvme nvme0: I/O %d QID %d timeout, completion polled" % (R.randrange(10, 400), R.randrange(1, 8))),
        ("sshd", 3, lambda: "error: kex_exchange_identification: Connection closed by remote host"),
        ("kernel", 2, lambda: "mce: [Hardware Error]: Corrected error, no action required. CPU %d" % R.randrange(0, 8)),
        ("CRON", 3, lambda: "(root) error: could not open /var/spool/cron/crontabs/%s" % R.choice(["backup", "ops"])),
    ]
def noise():
    return [
        ("systemd", 6, lambda: "Started %s.service - %s." % (unit(), R.choice(["Daemon", "Service", "Worker"]))),
        ("systemd", 6, lambda: "Started apport-error-report.service - Error reporting helper."),
        ("kernel", 6, lambda: "EXT4-fs (%s2): mounted filesystem with ordered data mode. Quota mode: none." % dev()),
        ("kernel", 4, lambda: "ACPI: \\_SB.PCI0.LPCB: ACPI Error: AE_NOT_FOUND, While resolving a named reference package element"),
        ("systemd", 4, lambda: "%s.service: Scheduled restart job, restart counter is at %d." % (unit(), R.randrange(1, 5))),
        ("kernel", 5, lambda: "random: crng init done"),
        ("sshd", 6, lambda: "Accepted publickey for ops from 10.%d.%d.%d port %d ssh2" % (R.randrange(0, 255), R.randrange(0, 255), R.randrange(2, 250), R.randrange(30000, 60000))),
        ("systemd-logind", 6, lambda: "New session %d of user ops." % R.randrange(1, 400)),
    ]

entries = []
expected = []
for i, (s, e) in enumerate(bounds):
    bid = ids[i]
    mono = 0
    rows = [("kernel", 6, "Linux version 6.8.0-%d-generic (buildd@lcy02) #%d-Ubuntu SMP PREEMPT_DYNAMIC" % (R.randrange(31, 60), R.randrange(31, 60))),
            ("systemd", 6, "systemd 255.4-1ubuntu8 running in system mode"),
            ("systemd", 6, "Reached target multi-user.target - Multi-User System.")]
    n_noise = R.randrange(12, 22)
    body = []
    for _ in range(n_noise):
        idn, pr, fn = R.choice(noise()); body.append((idn, pr, fn()))
    errs = []
    if i == crash:
        k = R.randrange(4, 7)
        pool = errors_crash()
        for _ in range(k):
            idn, pr, fn = R.choice(pool); errs.append((idn, pr, fn()))
    else:
        for _ in range(R.randrange(1, 4)):
            idn, pr, fn = R.choice(errors_clean()); errs.append((idn, pr, fn()))
    allrows = rows + body + errs
    middle = allrows[3:]
    R.shuffle(middle)
    allrows = allrows[:3] + middle
    if i != crash:
        allrows += [("systemd", 6, "Stopped target multi-user.target - Multi-User System."),
                    ("systemd-shutdown", 6, "Syncing filesystems and block devices."),
                    ("systemd-shutdown", 6, R.choice(["Powering off.", "Rebooting."]))]
    span = e - s
    stamps = sorted(R.sample(range(0, span * 1000), len(allrows)))
    for k, ((idn, pr, msg), off) in enumerate(zip(allrows, stamps)):
        ts = s * 1000000 + off * 1000 + R.randrange(0, 1000)
        entries.append({"boot": i, "ts": ts, "obj": {
            "__CURSOR": "s=%s;i=%x;b=%s;m=%x;t=%x;x=%s" % ("%032x" % R.getrandbits(128), len(entries) + 1, bid, off * 1000, ts, "%016x" % R.getrandbits(64)),
            "__REALTIME_TIMESTAMP": str(ts),
            "__MONOTONIC_TIMESTAMP": str(off * 1000),
            "_BOOT_ID": bid, "_HOSTNAME": host,
            "PRIORITY": str(pr), "SYSLOG_IDENTIFIER": idn,
            "_TRANSPORT": "kernel" if idn == "kernel" else "journal",
            "MESSAGE": msg}})
        if i == crash and pr <= 3:
            expected.append((ts, msg))

# two exports: A = crashed boot's first part + some boots, B = the rest
cb = sorted([x for x in entries if x["boot"] == crash], key=lambda x: x["ts"])
errpos = [j for j, x in enumerate(cb) if int(x["obj"]["PRIORITY"]) <= 3]
cut = cb[errpos[len(errpos) // 2]]["ts"]      # at least one error on each side
others = [b for b in range(nb) if b != crash]
R.shuffle(others)
a_boots = set(others[:1]); b_boots = set(others[1:])
A = [x for x in entries if (x["boot"] in a_boots) or (x["boot"] == crash and x["ts"] < cut)]
B = [x for x in entries if (x["boot"] in b_boots) or (x["boot"] == crash and x["ts"] >= cut)]
A.sort(key=lambda x: x["ts"]); B.sort(key=lambda x: x["ts"])
out = A + B if R.random() < 0.5 else B + A
if [x["ts"] for x in out] == sorted(x["ts"] for x in out):
    out = B + A if out is not (B + A) else A + B
with open("journal.json", "w") as f:
    for x in out:
        f.write(json.dumps(x["obj"], separators=(",", ":")) + "\n")
expected.sort()
open(".lm-state/crashed_boot", "w").write(ids[crash] + "\n")
open(".lm-state/crash_errors", "w").write("".join(m + "\n" for _, m in expected))
open(".lm-state/boot_ids", "w").write("\n".join(ids) + "\n")
PYEOF
[ -s journal.json ] || { echo "setup failed to write journal.json" >&2; exit 1; }
cksum journal.json > .lm-state/sum
