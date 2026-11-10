#!/bin/bash
# db-04's journal from 21:00 yesterday to now (frozen at 03:10, Europe/Berlin).
# The maintenance window began at 23:40 *yesterday* and included a reboot.
# The answer is every entry at priority err or more serious (crit, alert)
# since then, from both boots. Traps, all real-world:
#  - `--since 23:40` means 23:40 today (the future): "-- No entries --";
#    `--since "yesterday 23:40"` is rejected, as in systemd.
#  - `-b` keeps only the boot after the reboot.
#  - PostgreSQL maps its ERROR level to syslog *warning* (FATAL is err, PANIC
#    crit), pgbackrest prints "ERROR:" on stdout (info), the app logs
#    error_rate=... at info: words are not priorities.
#  - sshd "error: kex_exchange_identification" really is err; sudo's
#    "incorrect password attempts" really is alert.
# Which messages appear, and when, is random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"

mkdir -p bin .lm var/log/journal etc
cp "$M/systemd/journalctl" "$M/systemd/systemctl" bin/
echo db-04 > etc/hostname
echo Europe/Berlin > etc/timezone
echo "2026-11-10 03:10:00" > .lm/now

python3 - "$RANDOM$$" <<'PY'
import json, random, sys, uuid
from datetime import datetime, timezone, timedelta

rnd = random.Random(sys.argv[1])
CET = timezone(timedelta(hours=1))
def ts(day, h, m, s):                       # local wall time -> epoch seconds
    return datetime(2026, 11, day, h, m, s, tzinfo=CET).timestamp()

START = ts(9, 21, 0, 0)
MAINT = ts(9, 23, 40, 0)
END = ts(10, 3, 9, 30)
REBOOT = ts(10, 0, rnd.randint(28, 41), rnd.randint(0, 59))
BOOT_A, BOOT_B = uuid.UUID(int=rnd.getrandbits(128)).hex, uuid.UUID(int=rnd.getrandbits(128)).hex
HOST = "db-04"
entries = []

def add(t, prio, ident, msg, unit=None, pid=None, kernel=False):
    e = {"__REALTIME_TIMESTAMP": str(int(t * 1_000_000) + rnd.randint(0, 999_999)),
         "_BOOT_ID": BOOT_A if t < REBOOT else BOOT_B, "_HOSTNAME": HOST,
         "PRIORITY": str(prio), "SYSLOG_IDENTIFIER": ident, "MESSAGE": msg}
    if kernel:
        e["_TRANSPORT"] = "kernel"
    else:
        e["_TRANSPORT"] = "syslog" if ident in ("postgres", "sudo", "sshd", "CRON", "nginx", "smartd") else "stdout"
        e["_PID"] = str(pid)
    if unit:
        e["_SYSTEMD_UNIT"] = unit
    entries.append(e)

def pids():
    return {"postgres": rnd.randint(900, 1300), "nginx": rnd.randint(1300, 1500),
            "ledger": rnd.randint(1500, 2100), "sshd": rnd.randint(700, 900), "smartd": rnd.randint(600, 700)}
P = {BOOT_A: pids(), BOOT_B: pids()}
def pid(name, t):
    if name == "CRON":                      # a fresh process for every job
        return rnd.randint(2200, 9900)
    return P[BOOT_A if t < REBOOT else BOOT_B][name]

def ip():
    return rnd.choice(["45.148.10.", "141.98.11.", "193.32.162.", "218.92.0."]) + str(rnd.randint(2, 250))

# ---- background traffic over the whole span ------------------------------------
INFO = [
    (6, "postgres", "postgresql@16-main.service", lambda: "LOG:  checkpoint starting: time"),
    (6, "postgres", "postgresql@16-main.service", lambda: f"LOG:  checkpoint complete: wrote {rnd.randint(200, 4000)} buffers ({rnd.uniform(1, 20):.1f}%); 0 WAL file(s) added, 0 removed, {rnd.randint(1, 4)} recycled"),
    (6, "postgres", "postgresql@16-main.service", lambda: f"LOG:  automatic vacuum of table \"ledger.public.entries\": index scans: 1, pages: 0 removed, {rnd.randint(9000, 99000)} remain"),
    (4, "postgres", "postgresql@16-main.service", lambda: f"ERROR:  duplicate key value violates unique constraint \"entries_ref_key\""),
    (4, "postgres", "postgresql@16-main.service", lambda: "ERROR:  canceling statement due to statement timeout"),
    (6, "ledger", "ledger.service", lambda: f"health ok, error_rate={rnd.uniform(0, 0.3):.2f}% p99={rnd.randint(40, 180)}ms"),
    (6, "ledger", "ledger.service", lambda: f"batch {rnd.randint(70000, 79999)} committed, 0 failed rows"),
    (4, "ledger", "ledger.service", lambda: f"slow query ({rnd.randint(1200, 4800)}ms): SELECT ... FROM entries WHERE account_id = $1"),
    (6, "nginx", "nginx.service", lambda: f"*{rnd.randint(1000, 99999)} client {ip()} closed keepalive connection"),
    (4, "nginx", "nginx.service", lambda: f"*{rnd.randint(1000, 99999)} an upstream response is buffered to a temporary file /var/cache/nginx/proxy_temp/{rnd.randint(1, 9)}/00/00000{rnd.randint(1000, 9999)}"),
    (6, "sshd", "ssh.service", lambda: f"Connection closed by {ip()} port {rnd.randint(30000, 65000)} [preauth]"),
    (3, "sshd", "ssh.service", lambda: f"error: kex_exchange_identification: Connection closed by remote host"),
    (6, "CRON", "cron.service", lambda: "pam_unix(cron:session): session opened for user postgres(uid=114) by (uid=0)"),
    (5, "kernel", None, lambda: f"[UFW BLOCK] IN=ens3 OUT= SRC={ip()} DST=10.0.2.4 PROTO=TCP SPT={rnd.randint(30000, 65000)} DPT=5432 SYN"),
]
t = START + rnd.randint(5, 60)
while t < END:
    prio, ident, unit, f = rnd.choice(INFO)
    if prio == 3 and rnd.random() < 0.6:          # keep the sshd noise modest
        prio, ident, unit, f = INFO[0]
    if ident == "kernel":
        add(t, prio, "kernel", f(), kernel=True)
    elif not (REBOOT - 120 < t < REBOOT + 60):    # services are down around the reboot
        add(t, prio, ident, f(), unit, pid(ident, t))
    t += rnd.randint(25, 140)

# ---- serious events before the window (decoys) ---------------------------------
before = [
    (3, "ledger", "ledger.service", "unable to reach postgres at 127.0.0.1:5432: connection timed out"),
    (3, "postgres", "postgresql@16-main.service", "FATAL:  password authentication failed for user \"report\""),
    (2, "smartd", "smartd.service", "Device: /dev/sdb [SAT], 8 Currently unreadable (pending) sectors"),
    (3, "kernel", None, "EXT4-fs error (device sdb1): ext4_find_entry:1683: inode #131074: comm pg_basebackup: reading directory lblock 0"),
]
for prio, ident, unit, msg in rnd.sample(before, 3):
    tt = rnd.uniform(START + 600, MAINT - 900)
    add(tt, prio, ident, msg, unit, None if ident == "kernel" else pid(ident, tt), kernel=(ident == "kernel"))
# one right before the window opens
add(MAINT - rnd.randint(5, 40), 3, "ledger", "write to postgres failed: server closed the connection unexpectedly", "ledger.service", pid("ledger", MAINT))

# ---- the maintenance window ----------------------------------------------------
t = MAINT + rnd.randint(3, 50)
add(t, 6, "sudo", "  dba : TTY=pts/0 ; PWD=/home/dba ; USER=root ; COMMAND=/usr/bin/systemctl stop ledger.service", None, rnd.randint(3000, 3500))
t += rnd.randint(30, 120)
add(t, 6, "ledger", "SIGTERM received, draining 3 workers (error budget unaffected)", "ledger.service", pid("ledger", t))
t += rnd.randint(60, 300)
add(t, 6, "postgres", "LOG:  received fast shutdown request", "postgresql@16-main.service", pid("postgres", t))
add(t + 1, 3, "postgres", "FATAL:  terminating connection due to administrator command", "postgresql@16-main.service", pid("postgres", t))
add(t + 2, 6, "postgres", "LOG:  database system is shut down", "postgresql@16-main.service", pid("postgres", t))
t += rnd.randint(120, 400)
if rnd.random() < 0.7:
    add(t, 1, "sudo", "  intern : 3 incorrect password attempts ; TTY=pts/1 ; PWD=/home/intern ; USER=root ; COMMAND=/usr/bin/apt full-upgrade", None, rnd.randint(3500, 4000))
t += rnd.randint(60, 300)
add(t, 6, "pgbackrest", "INFO: backup command begin 2.53: --stanza=ledger --type=full", "pgbackrest-full.service", rnd.randint(4000, 4500))
add(t + rnd.randint(20, 90), 6, "pgbackrest", f"ERROR: [082]: WAL segment 00000001000000{rnd.randint(16, 99)}000000F1 was not archived before the 60000ms timeout", "pgbackrest-full.service", rnd.randint(4000, 4500))
add(t + rnd.randint(100, 200), 3, "systemd", "Failed to start pgbackrest-full.service - pgBackRest full backup.", None, 1)
entries[-1]["UNIT"] = "pgbackrest-full.service"; entries[-1]["_SYSTEMD_UNIT"] = "init.scope"
t = REBOOT - rnd.randint(20, 60)
add(t, 6, "systemd", "Stopping ledger.service - Ledger API...", None, 1)
add(REBOOT - 2, 6, "systemd", "Reached target reboot.target - System Reboot.", None, 1)

# boot B
b = REBOOT + rnd.randint(40, 90)
for i, (prio, msg) in enumerate([
        (5, "Linux version 6.8.0-49-generic (buildd@lcy02-amd64-031) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.2.0-23ubuntu4) 13.2.0) #49-Ubuntu SMP PREEMPT_DYNAMIC"),
        (6, "Command line: BOOT_IMAGE=/vmlinuz-6.8.0-49-generic root=UUID=0b6f6c7e-61a2-4c4b-9c55-3a1f0c4d7e21 ro"),
        (3, f"ACPI BIOS Error (bug): Could not resolve symbol [\\_SB.PC00.PEG1.PEGP], AE_NOT_FOUND ({rnd.randint(20230000, 20231231)}/dswload2-162)"),
        (6, "EXT4-fs (sda2): mounted filesystem 0b6f6c7e-61a2-4c4b-9c55-3a1f0c4d7e21 ro with ordered data mode. Quota mode: none."),
        (4, "EXT4-fs (sdb1): warning: mounting fs with errors, running e2fsck is recommended"),
        (6, "EXT4-fs (sdb1): mounted filesystem 9d1c2e40-7b11-4e0e-8f2a-1f4e2b9c0aa7 r/w with ordered data mode. Quota mode: none.")]):
    add(b + i * 0.4, prio, "kernel", msg, kernel=True)
b += 8
add(b, 6, "postgres", "LOG:  starting PostgreSQL 16.4 (Ubuntu 16.4-1.pgdg24.04+1) on x86_64-pc-linux-gnu", "postgresql@16-main.service", pid("postgres", b))
add(b + 1, 6, "postgres", "LOG:  database system was shut down at " + datetime.fromtimestamp(REBOOT - 600, CET).strftime("%Y-%m-%d %H:%M:%S CET"), "postgresql@16-main.service", pid("postgres", b))
add(b + 2, 6, "ledger", "ledger 7.2.0 starting", "ledger.service", pid("ledger", b))
add(b + 3, 3, "ledger", "unable to reach postgres at 127.0.0.1:5432: connection refused", "ledger.service", pid("ledger", b))
add(b + 4, 5, "systemd", "ledger.service: Main process exited, code=exited, status=1/FAILURE", None, 1)
entries[-1]["UNIT"] = "ledger.service"
add(b + 4.1, 4, "systemd", "ledger.service: Failed with result 'exit-code'.", None, 1)
entries[-1]["UNIT"] = "ledger.service"
add(b + 4.2, 3, "systemd", "Failed to start ledger.service - Ledger API.", None, 1)
entries[-1]["UNIT"] = "ledger.service"
add(b + 9, 6, "postgres", "LOG:  database system is ready to accept connections", "postgresql@16-main.service", pid("postgres", b))
add(b + 15, 6, "ledger", "ledger 7.2.0 starting", "ledger.service", pid("ledger", b) + 40)
add(b + 16, 6, "ledger", "connected to postgres, replaying 0 failed batches", "ledger.service", pid("ledger", b) + 40)
for k, v in P[BOOT_B].items():
    if k == "ledger":
        P[BOOT_B][k] = v + 40

later = [
    (2, "ledger", "ledger.service", lambda: f"ledger checksum mismatch in batch {rnd.randint(70000, 79999)}, halting writes for account range 4000-4999"),
    (3, "kernel", None, lambda: f"EXT4-fs error (device sdb1): ext4_validate_block_bitmap:{rnd.randint(380, 440)}: comm postgres: bg {rnd.randint(10, 300)}: bad block bitmap checksum"),
    (2, "smartd", "smartd.service", lambda: f"Device: /dev/sdb [SAT], {rnd.randint(9, 40)} Currently unreadable (pending) sectors"),
    (3, "postgres", "postgresql@16-main.service", lambda: f"FATAL:  could not open file \"base/16384/{rnd.randint(16000, 26000)}\": Input/output error"),
    (3, "nginx", "nginx.service", lambda: f"*{rnd.randint(1000, 99999)} connect() failed (111: Connection refused) while connecting to upstream, client: 10.0.4.{rnd.randint(2, 60)}, server: ledger.internal, request: \"POST /api/entries HTTP/1.1\", upstream: \"http://127.0.0.1:8070/api/entries\", host: \"ledger.internal\""),
    (3, "ledger", "ledger.service", lambda: "write to postgres failed: could not read block: Input/output error"),
]
for _ in range(rnd.randint(5, 8)):
    prio, ident, unit, f = rnd.choice(later)
    tt = rnd.uniform(b + 120, END - 30)
    add(tt, prio, ident, f(), unit, None if ident == "kernel" else pid(ident, tt), kernel=(ident == "kernel"))

entries.sort(key=lambda e: int(e["__REALTIME_TIMESTAMP"]))
with open("var/log/journal/system.json", "w") as fh:
    for e in entries:
        fh.write(json.dumps(e) + "\n")
with open(".lm/boot_id", "w") as fh:
    fh.write(BOOT_B + "\n")
PY
cksum var/log/journal/system.json > .lm/journal.sum
