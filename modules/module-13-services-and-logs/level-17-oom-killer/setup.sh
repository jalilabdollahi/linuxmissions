#!/bin/bash
# OOM-killed: reports.service (a JVM report engine) died last night. The
# journal (var/log/journal/, mock journalctl) holds two kernel OOM kills of
# reports' java process (two nights, different anon-rss) and one of another
# "java": a Docker container's cgroup, with a larger anon-rss (decoy). The
# policy wants MemoryMax = 1.5 x the largest anon-rss of the unit's killed
# processes, rounded up to the next 256M. anon-rss is in kB (KiB): dividing
# by 1000 gives a different answer, and setup makes sure it does. The limit
# and all sizes are random per setup. Mock systemctl/journalctl in bin/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin .lm/systemd/units .lm-state var/log/journal etc/systemd/system/multi-user.target.wants opt/reports/bin
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
echo rep-01 > etc/hostname
echo "2026-11-10 08:40:00" > .lm/now

python3 - "$RANDOM$$" <<'PY'
import json, math, random, sys, uuid
from datetime import datetime, timezone

R = random.Random(int(sys.argv[1]))
HOST = "rep-01"
BOOT = uuid.UUID(int=R.getrandbits(128)).hex
STEP = 256 * 1024 * 1024

def want(kb_peak, unit_kb=1024):
    return math.ceil(kb_peak * unit_kb * 1.5 / STEP) * STEP

# Limit and sizes, re-rolled until the classic mistakes give other answers.
while True:
    limit_m = R.choice([768, 1024, 1280, 1536, 2048])
    lim_kb = limit_m * 1024
    a1 = int(lim_kb * R.uniform(0.74, 0.97))       # night 1
    a2 = int(lim_kb * R.uniform(0.74, 0.97))       # night 2 (the one that left it dead)
    dk = int(R.uniform(2.6, 3.4) * 1024 * 1024)    # the container's java
    peak = max(a1, a2)
    w = want(peak)
    if want(peak, 1000) != w and want(dk) != w and w > limit_m * 1024 * 1024 and want(min(a1, a2)) != w:
        break

entries = []
def ts(s):
    return int(datetime.strptime(s, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).timestamp() * 1e6)

def E(t, ident, msg, prio=6, pid=None, unit=None, kernel=False, sysunit=None, us=0):
    e = {"__REALTIME_TIMESTAMP": str(ts(t) + us), "_BOOT_ID": BOOT, "_HOSTNAME": HOST,
         "PRIORITY": str(prio), "SYSLOG_IDENTIFIER": ident, "MESSAGE": msg}
    if kernel:
        e["_TRANSPORT"] = "kernel"
    else:
        e["_PID"] = str(pid or 1)
    if unit:
        e["UNIT"] = unit
    if sysunit:
        e["_SYSTEMD_UNIT"] = sysunit
    entries.append(e)

def oom(t, comm, pid, memcg, anon_kb, lim_kb, others):
    k = lambda m, p=6, us=0: E(t, "kernel", m, p, kernel=True, us=us)
    k("%s invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0" % comm, 4)
    k("CPU: %d PID: %d Comm: %s Not tainted 6.8.0-48-generic #48-Ubuntu" % (R.randint(0, 7), pid, comm), us=10)
    k("Hardware name: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014", us=12)
    k("memory: usage %dkB, limit %dkB, failcnt %d" % (lim_kb, lim_kb, R.randint(200, 9000)), us=40)
    k("swap: usage 0kB, limit 9007199254740988kB, failcnt 0", us=41)
    k("Memory cgroup stats for %s:" % memcg, us=42)
    k("Tasks state (memory values in pages):", us=60)
    k("[  pid  ]   uid  tgid total_vm      rss pgtables_bytes swapents oom_score_adj name", us=61)
    for (p, name, rss_pages) in [(pid, comm, anon_kb // 4)] + others:
        k("[%7d]   998 %5d %8d %8d %14d        0             0 %s" % (p, p, rss_pages * 3, rss_pages, rss_pages * 8, name), us=62)
    k("oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=%s,task_memcg=%s,task=%s,pid=%d,uid=998" % (memcg, memcg, comm, pid), us=80)
    k("Memory cgroup out of memory: Killed process %d (%s) total-vm:%dkB, anon-rss:%dkB, file-rss:%dkB, shmem-rss:0kB, UID:998 pgtables:%dkB oom_score_adj:0"
      % (pid, comm, anon_kb * 3 + R.randint(1000, 90000), anon_kb, R.randint(9000, 30000), anon_kb // 400), 3, us=81)

def reports_night(day, hh, anon, pid):
    t0 = "2026-11-%02d %02d:%02d:00" % (day, hh, R.randint(0, 20))
    E(t0, "systemd", "Started reports.service - Nightly reports (report engine on the JVM).", unit="reports.service")
    E(t0, "systemd", "Finished reports.timer - Run the nightly reports.", unit="reports.timer", us=-1000)
    E(t0, "report-engine", "report-engine 9.2 starting, -Xmx unset, heap sized by the JVM", pid=pid, sysunit="reports.service", us=500000)
    for i, rep in enumerate(R.sample(["monthly-invoices", "stock-aging", "churn-cohorts", "vat-summary", "ledger-export"], 3)):
        E("2026-11-%02d %02d:%02d:%02d" % (day, hh, 25 + i * 9, R.randint(0, 59)), "report-engine",
          "building %s (rows: %dM)" % (rep, R.randint(2, 40)), pid=pid, sysunit="reports.service")
    tk = "2026-11-%02d %02d:%02d:%02d" % (day, hh + 1, R.randint(0, 50), R.randint(0, 59))
    E(tk, "report-engine", "GC overhead high: %d%% of time in GC over last 60s" % R.randint(60, 95), 4, pid=pid, sysunit="reports.service")
    oom(tk, "java", pid, "/system.slice/reports.service", anon, lim_kb, [(pid + 179, "wkhtmltopdf", R.randint(9000, 40000))])
    E(tk, "systemd", "reports.service: A process of this unit has been killed by the OOM killer.", 4, unit="reports.service", us=200000)
    E(tk, "systemd", "reports.service: Main process exited, code=killed, status=9/KILL", 5, unit="reports.service", us=210000)
    E(tk, "systemd", "reports.service: Failed with result 'oom-kill'.", 4, unit="reports.service", us=220000)
    E(tk, "systemd", "reports.service: Consumed %dmin %d.%03ds CPU time." % (R.randint(30, 80), R.randint(0, 59), R.randint(0, 999)), 6, unit="reports.service", us=230000)
    return tk

pid1 = R.randint(40000, 49000)
pid2 = R.randint(51000, 59000)
k1 = reports_night(9, R.choice([1, 2]), a1, pid1)
E("2026-11-09 09:12:44", "sudo", "  ops-anna : TTY=pts/0 ; PWD=/home/ops-anna ; USER=root ; COMMAND=/usr/bin/systemctl start reports.service", 5, pid=R.randint(9000, 9999))
E("2026-11-09 09:12:44", "systemd", "Started reports.service - Nightly reports (report engine on the JVM).", unit="reports.service", us=300000)
E("2026-11-09 09:58:10", "report-engine", "all reports done, exiting", pid=R.randint(60000, 69000), sysunit="reports.service")
E("2026-11-09 09:58:10", "systemd", "reports.service: Deactivated successfully.", unit="reports.service", us=90000)
# The container's java, between the two nights.
cid = "%064x" % R.getrandbits(256)
cpid = R.randint(30000, 39000)
tc = "2026-11-10 00:%02d:%02d" % (R.randint(10, 50), R.randint(0, 59))
oom(tc, "java", cpid, "/system.slice/docker-%s.scope" % cid, dk, dk + R.randint(20000, 90000), [])
E(tc, "systemd", "docker-%s.scope: A process of this unit has been killed by the OOM killer." % cid, 4, unit="docker-%s.scope" % cid, us=200000)
E(tc, "dockerd", 'time="%sZ" level=info msg="ignoring event" container=%s module=libcontainerd namespace=moby topic=/tasks/oom type="*events.TaskOOM"' % (tc.replace(" ", "T"), cid[:12]), pid=1123, sysunit="docker.service", us=400000)
k2 = reports_night(10, R.choice([2, 3]), a2, pid2)

# Background noise over both days.
for day in (9, 10):
    for h in range(0, 24 if day == 9 else 9):
        for m in (5, 35):
            E("2026-11-%02d %02d:%02d:01" % (day, h, m), "CRON", "(root) CMD (command -v debian-sa1 > /dev/null && debian-sa1 1 1)", pid=R.randint(20000, 29999), sysunit="cron.service")
        if R.random() < 0.3:
            E("2026-11-%02d %02d:%02d:%02d" % (day, h, R.randint(0, 59), R.randint(0, 59)), "sshd",
              "Accepted publickey for deploy from 10.0.9.%d port %d ssh2: ED25519 SHA256:q1Xb" % (R.randint(2, 40), R.randint(40000, 60000)), pid=R.randint(30000, 39999), sysunit="ssh.service")
        if R.random() < 0.4:
            E("2026-11-%02d %02d:%02d:%02d" % (day, h, R.randint(0, 59), R.randint(0, 59)), "kernel",
              "[UFW BLOCK] IN=ens3 OUT= SRC=%d.%d.%d.%d DST=10.0.3.21 PROTO=TCP SPT=%d DPT=%d SYN" % (R.randint(1, 223), R.randint(0, 255), R.randint(0, 255), R.randint(1, 254), R.randint(1024, 65000), R.choice([22, 3389, 5432])), 4, kernel=True)

entries.sort(key=lambda e: int(e["__REALTIME_TIMESTAMP"]))
with open("var/log/journal/system.json", "w") as f:
    for e in entries:
        f.write(json.dumps(e) + "\n")
with open(".lm-state/limit", "w") as f:
    f.write("%dM\n" % limit_m)
with open(".lm-state/killed", "w") as f:
    f.write("%s %d\n%s %d\n" % (k1, pid1, k2, pid2))
PY

LIMIT=$(cat .lm-state/limit)
cat > etc/systemd/system/reports.service <<EOF
[Unit]
Description=Nightly reports (report engine on the JVM)
After=network-online.target postgresql.service

[Service]
Type=simple
User=reports
ExecStart=/opt/reports/bin/report-engine
MemoryMax=$LIMIT
Restart=no

[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/reports.service etc/systemd/system/multi-user.target.wants/reports.service

cat > opt/reports/bin/report-engine <<'EOF'
#!/bin/bash
# report-engine (stand-in for the JVM): builds the nightly reports.
echo "report-engine 9.2 starting, -Xmx unset, heap sized by the JVM"
while :; do
  sleep 25
  echo "report-engine: idle, next run 01:00"
done
EOF
chmod +x opt/reports/bin/report-engine

cat > POLICY.md <<'EOF'
# Memory limits for OOM-killed services (ops runbook, section 4.2)

When the kernel OOM-kills a process of a systemd service because the service
hit its MemoryMax:

1. Find the service's kills in the journal (kernel messages). Only kills in
   the service's own cgroup count (task_memcg=/system.slice/<unit>).
2. Take the largest anon-rss of those killed processes.
3. New MemoryMax = 1.5 x that, rounded UP to the next multiple of 256M.
   (anon-rss is printed in kB; the kernel's kB are 1024 bytes.)
4. Apply it with `systemctl set-property <unit> MemoryMax=...` so it is
   recorded as a control drop-in, then start the service again.
EOF

# The state systemd had after last night's kill.
pid2=$(awk 'NR == 2 { print $3 }' .lm-state/killed)
kt=$(awk 'NR == 2 { print $1, $2 }' .lm-state/killed)
cat > .lm/systemd/units/reports.service.state <<EOF
ActiveState=failed
SubState=failed
Result=oom-kill
ExecMainPID=$pid2
ExecMainCode=killed
ExecMainStatus=9
MainPID=0
StateChangeTimestamp=$kt
InactiveEnterTimestamp=$kt
EOF
bin/systemctl daemon-reload
