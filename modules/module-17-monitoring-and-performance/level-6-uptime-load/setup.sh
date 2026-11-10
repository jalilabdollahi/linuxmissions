#!/bin/bash
# Eight hosts. uptime.txt: "host: <uptime line>" with the uptime part in all the
# shapes real uptime prints (days+clock, days only mins, minutes, hours:minutes).
# inventory.tsv: host<TAB>nproc. Roles (random hosts): 2-3 overloaded, one at
# exactly 1.00 per CPU on load5, one with a high 1-min only, one with a high
# 15-min only, the rest fine.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
pool = ["web-01", "web-02", "web-03", "db-01", "db-02", "cache-01", "queue-01", "batch-01", "api-01", "api-02", "mail-01", "ldap-01"]
hosts = R.sample(pool, 8)
roles = ["over"] * R.choice([2, 3]) + ["exact", "spike", "old"]
roles += ["fine"] * (8 - len(roles))
R.shuffle(roles)
ups = ["up 3 days,  2:11,  2 users", "up 14 min,  1 user", "up 1 day,  4:05,  1 user", "up 21:08,  0 users",
       "up 47 days, 19:30,  3 users", "up 2 min,  1 user", "up 9 days,  6 min,  2 users", "up 5:42,  1 user"]
R.shuffle(ups)
inv, lines, over = [], [], []
for h, role, up in zip(hosts, roles, ups):
    n = R.choice([2, 4, 4, 8, 16])
    if role == "over":
        l5 = round(n * R.uniform(1.15, 2.4), 2); l1 = round(l5 * R.uniform(0.8, 1.3), 2); l15 = round(l5 * R.uniform(0.5, 1.1), 2)
        over.append(h)
    elif role == "exact":
        l5 = float(n); l1 = round(n * R.uniform(0.7, 1.3), 2); l15 = round(n * R.uniform(0.7, 1.2), 2)
    elif role == "spike":
        l5 = round(n * R.uniform(0.3, 0.8), 2); l1 = round(n * R.uniform(1.4, 2.5), 2); l15 = round(n * R.uniform(0.2, 0.6), 2)
    elif role == "old":
        l5 = round(n * R.uniform(0.3, 0.8), 2); l1 = round(n * R.uniform(0.2, 0.7), 2); l15 = round(n * R.uniform(1.3, 2.0), 2)
    else:
        l5 = round(n * R.uniform(0.05, 0.85), 2); l1 = round(n * R.uniform(0.05, 0.9), 2); l15 = round(n * R.uniform(0.05, 0.9), 2)
    # a 5-minute load computed with float noise must not land on the boundary by accident
    if role != "exact" and abs(l5 / n - 1.0) < 0.05:
        l5 = round(n * 0.7, 2) if role != "over" else round(n * 1.3, 2)
    lines.append("%s: %02d:%02d:%02d %s,  load average: %.2f, %.2f, %.2f" % (h, R.randint(0, 23), R.randint(0, 59), R.randint(0, 59), up, l1, l5, l15))
    inv.append("%s\t%d" % (h, n))
R.shuffle(inv)
open("uptime.txt", "w").write("\n".join(lines) + "\n")
open("inventory.tsv", "w").write("\n".join(inv) + "\n")
open(".lm-state/want", "w").write("\n".join(sorted(over)) + "\n")
PY
