#!/bin/bash
# Six `ping -c 50` runs over the VPN, one per site. Which site has which
# problem changes per setup. RTTs are generated per packet and the summary
# (min/avg/max/mdev) is computed from them the way iputils does.
SANDBOX="$1"
mkdir -p "$SANDBOX/pings"

python3 - "$SANDBOX/pings" <<'PY'
import math, random, sys
out = sys.argv[1]
sites = {"frankfurt": "10.81.0.1", "amsterdam": "10.82.0.1", "london": "10.83.0.1",
         "newyork": "10.91.0.1", "singapore": "10.94.0.1", "sydney": "10.96.0.1"}
roles = ["clean", "lossy", "jittery", "both", "dup", "down"]
random.shuffle(roles)
N = 50

def stats(ts):
    avg = sum(ts) / len(ts)
    mdev = math.sqrt(max(sum(t * t for t in ts) / len(ts) - avg * avg, 0))
    return min(ts), avg, max(ts), mdev

for (site, ip), role in zip(sites.items(), roles):
    host = f"vpn-{site}.corp.example"
    base = random.uniform(8, 160)
    want_jitter = role in ("jittery", "both") or (role == "dup" and random.random() < 0.5)
    lost, errors, dups = set(), {}, []
    if role in ("lossy", "both"):
        lost = set(random.sample(range(1, N + 1), random.choice([3, 4, 5]) if role == "lossy" else 2 + random.randint(0, 2)))
        if role == "lossy":
            for seq in random.sample(sorted(lost), 2):
                errors[seq] = "Destination Host Unreachable"
    elif role == "dup":
        lost = {random.randint(2, N)}          # exactly 2 % loss: not above the limit
        dups = random.sample([s for s in range(1, N + 1) if s not in lost], 3)
    elif role == "down":
        lost = set(range(1, N + 1))
        errors = {s: "Destination Host Unreachable" for s in range(1, N + 1) if s % 13 != 1}
    while True:
        sd = random.uniform(26, 40) if want_jitter else random.uniform(0.8, 12)
        times = {s: max(base * 0.6, random.gauss(base, sd)) for s in range(1, N + 1) if s not in lost}
        if not times:
            break
        ts = list(times.values())
        m = stats(ts)[3]
        if (want_jitter and m > 22) or (not want_jitter and m < 17):
            break
    lines = [f"PING {host} ({ip}) 56(84) bytes of data."]
    ttl = random.choice([54, 55, 57, 58, 60])
    for s in range(1, N + 1):
        if s in times:
            lines.append(f"64 bytes from {host} ({ip}): icmp_seq={s} ttl={ttl} time={times[s]:.{1 if times[s] >= 100 else 2}f} ms")
            if s in dups:
                lines.append(f"64 bytes from {host} ({ip}): icmp_seq={s} ttl={ttl} time={times[s] + random.uniform(0.1, 3):.2f} ms (DUP!)")
        elif s in errors:
            lines.append(f"From 10.{ip.split('.')[1]}.0.254 icmp_seq={s} {errors[s]}")
    rec = len(times)
    loss = (N - rec) * 100 / N
    parts = [f"{N} packets transmitted", f"{rec} received"]
    if dups:
        parts.append(f"+{len(dups)} duplicates")
    if errors:
        parts.append(f"+{len(errors)} errors")
    parts.append(f"{loss:g}% packet loss")
    parts.append(f"time {(N - 1) * 1000 + random.randint(20, 400)}ms")
    lines += ["", f"--- {host} ping statistics ---", ", ".join(parts)]
    if times:
        mn, avg, mx, md = stats(list(times.values()))
        pipe = ", pipe 2" if errors else ""
        lines.append(f"rtt min/avg/max/mdev = {mn:.3f}/{avg:.3f}/{mx:.3f}/{md:.3f} ms{pipe}")
    else:
        lines.append("pipe 4")
    with open(f"{out}/{site}.txt", "w") as f:
        f.write("\n".join(lines) + "\n")
PY

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-7734  "The VPN is laggy"
-------------------------------
Users at several sites say the VPN is slow. The NOC ran `ping -c 50`
from the hub to the VPN gateway of every site; the outputs are in pings/
(one file per site, named after the site).

For the provider escalation we need two lists of site names (the file
name without .txt), one per line:
  lossy.txt    sites with packet loss above 2 %
  jittery.txt  sites whose jitter (the mdev of the rtt line) is above 20 ms
EOF
