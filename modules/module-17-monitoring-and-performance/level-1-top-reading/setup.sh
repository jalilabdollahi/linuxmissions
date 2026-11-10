#!/bin/bash
# A captured `top -b -n1` (numbers random per setup) and an empty summary.env.
# RES mixes plain KiB, "NNNm" and "N.Ng": the champion is a "g" value, while the
# biggest plain number (and the biggest text) belongs to a smaller process.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
total_mib = 15953.7
load = (round(R.uniform(6, 14), 2), round(R.uniform(4, 9), 2), round(R.uniform(1, 4), 2))
wa = round(R.uniform(22, 48), 1)
zombies = R.randint(1, 5)
us, sy = round(R.uniform(3, 12), 1), round(R.uniform(1, 6), 1)
idle = round(100 - wa - us - sy - 0.7, 1)

names = ["postgres", "postgres", "postgres", "postgres", "java", "redis-server", "nginx", "nginx",
         "node", "sshd", "rsyslogd", "cron", "systemd-journal", "python3", "backup-agent",
         "node_exporter", "dbus-daemon", "chronyd", "gunicorn", "gunicorn", "kworker/u8:2", "bash"]
pids = R.sample(range(300, 31000), len(names))
# RES in KiB; the champion is in the g range
champ = int(R.uniform(1.3, 1.9) * 1048576)
second_g = int(R.uniform(1.0, 1.2) * 1048576)
plain_max = R.randint(930000, 999000)             # shown as plain digits, sorts "highest"
m_vals = [R.randint(600, 920) * 1024 for _ in range(3)]
res = [champ, second_g, plain_max] + m_vals
rest = [R.randint(2000, 400000) for _ in range(len(names) - len(res))]
res += rest
order = list(range(len(names)))
R.shuffle(order)

def fmt(kib):
    if kib >= 1048576:
        return "%.1fg" % (kib / 1048576.0)
    if kib >= 600 * 1024 and kib % 1024 == 0:
        return "%dm" % (kib // 1024)
    return str(kib)

rows = []
for n in range(len(names)):
    rows.append((pids[n], names[n], res[n]))
champ_pid = rows[0][0]
rows_shuffled = rows[:]
R.shuffle(rows_shuffled)
# turn `zombies` of the small ones into Z tasks
small = [i for i, r in enumerate(rows_shuffled) if r[2] < 400000 and r[2] > 2000]
for i in R.sample(small, zombies):
    p, n, _ = rows_shuffled[i]
    rows_shuffled[i] = (p, n, 0)

lines = []
lines.append("top - 10:41:07 up 12 days,  3:41,  2 users,  load average: %.2f, %.2f, %.2f" % load)
lines.append("Tasks: %3d total,   %d running, %3d sleeping,   0 stopped,   %d zombie" % (187, R.randint(1, 4), 187 - 3 - zombies, zombies))
lines.append("%%Cpu(s): %4.1f us, %4.1f sy,  0.0 ni, %4.1f id, %4.1f wa,  0.0 hi,  0.7 si,  0.0 st" % (us, sy, idle, wa))
used = round(total_mib - 312.4 - 3630.1, 1)
lines.append("MiB Mem : %8.1f total, %8.1f free, %8.1f used, %8.1f buff/cache" % (total_mib, 312.4, used, 3630.1))
lines.append("MiB Swap: %8.1f total, %8.1f free, %8.1f used. %8.1f avail Mem" % (4096.0, 2900.1, 1195.9, 3200.2))
lines.append("")
lines.append("    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND")
for p, n, r in rows_shuffled:
    st = "Z" if r == 0 else R.choice("SSSSR") if False else ("Z" if r == 0 else R.choice(["S", "S", "S", "D", "R"]))
    user = {"postgres": "postgres", "java": "app", "redis-server": "redis", "nginx": "www-data"}.get(n, R.choice(["root", "app"]))
    virt = int(r * R.uniform(1.4, 3.0)) if r else 0
    cpu = 0.0 if st in "SZ" else round(R.uniform(0.3, 9.0), 1)
    mem = round(r / 1024.0 / total_mib * 100, 1)
    lines.append("%7d %-8s  20   0 %7s %6s %6d %s %5.1f %5.1f %5d:%02d.%02d %s" % (
        p, user[:8], virt, fmt(r) if r else 0, R.randint(800, 9000) if r else 0, st, cpu, mem,
        R.randint(0, 900), R.randint(0, 59), R.randint(0, 99), n))
open("top.txt", "w").write("\n".join(lines) + "\n")
open("summary.env", "w").write("LOAD1=\nLOAD15=\nIOWAIT=\nZOMBIES=\nTOP_MEM_PID=\n")
# the answer a text/plain-number sort would give
wrong = [p for p, n, r in rows_shuffled if r == plain_max][0]
open(".lm-state/want", "w").write("LOAD1=%.2f\nLOAD15=%.2f\nIOWAIT=%.1f\nZOMBIES=%d\nTOP_MEM_PID=%d\nWRONG_PID=%d\n" % (
    load[0], load[2], wa, zombies, champ_pid, wrong))
PY
