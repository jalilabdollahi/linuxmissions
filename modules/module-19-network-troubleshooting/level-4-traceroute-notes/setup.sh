#!/bin/bash
# traceroute and mtr from app-07 to the payment provider. The path breaks
# after the provider's edge; one router in the middle rate-limits ICMP (no
# replies, but the path goes on); one hop adds an ocean crossing. Hop numbers,
# addresses and latencies change per setup.
SANDBOX="$1"

python3 - "$SANDBOX" <<'PY'
import random, sys
sb = sys.argv[1]
r = random.randint
last = r(11, 15)                         # last hop that answers
silent = r(4, last - 4)                  # rate-limits ICMP: * * * / ??? in the middle
jump = random.choice([h for h in range(5, last) if h not in (silent, silent + 1)])
spike = random.choice([h for h in range(3, jump) if h != silent] or [2])

def ip_for(h):
    if h == 1: return "10.20.4.1", "_gateway"
    if h == 2: return f"100.64.{r(0, 63)}.1", None
    if h == last: return f"203.0.113.{r(2, 9)}", "edge-fw1.payprovider.example"
    if h < jump:
        x = f"198.51.100.{r(10, 250)}"
        return x, f"ae{r(1, 9)}-0.cr{r(1, 4)}.fra{r(1, 3)}.carrier-a.example"
    x = f"192.0.2.{r(10, 250)}"
    return x, f"be{r(10, 99)}.core{r(1, 6)}.nyc{r(1, 3)}.carrier-b.example"

hops, avg = {}, 0.0
for h in range(1, last + 1):
    if h == 1: avg = random.uniform(0.3, 0.6)
    elif h == 2: avg = random.uniform(1.4, 2.6)
    elif h == jump: avg += random.uniform(58, 115)
    else: avg += random.uniform(0.4, 4.5)
    ip, name = ip_for(h)
    hops[h] = (ip, name, avg)

# --- traceroute (no -n: names with the address in parentheses)
dest = f"203.0.113.{r(60, 99)}"
lines = [f"traceroute to api.payprovider.example ({dest}), 30 hops max, 60 byte packets"]
for h in range(1, 31):
    if h > last or h == silent:
        lines.append(f"{h:2d}  * * *")
        continue
    ip, name, a = hops[h]
    probes = [a + random.uniform(-0.15, 0.15) * max(a, 1) for _ in range(3)]
    if h == spike:
        probes[1] = a + random.uniform(60, 90)          # one slow probe: not a jump
    shown = [f"{p:.3f} ms" for p in probes]
    if h == last:
        shown[1] = "*"
    label = f"{name} ({ip})" if name else f"{ip} ({ip})"
    lines.append(f"{h:2d}  {label}  " + "  ".join(shown))
open(f"{sb}/traceroute.txt", "w").write("\n".join(lines) + "\n")

# --- mtr --report -n
lines = ["Start: 2026-11-10T09:14:03+0000",
         f"{'HOST: app-07':<45}Loss%   Snt   Last   Avg  Best  Wrst StDev"]
def row(h, host, loss, last_, a, best, worst, sd):
    return f"{h:3d}.|-- {host:<37}{loss:>6}  {20:4d} {last_:6.1f} {a:5.1f} {best:5.1f} {worst:5.1f} {sd:5.1f}"
for h in range(1, last + 3):
    if h > last or h == silent:
        lines.append(row(h, "???", "100.0", 0, 0, 0, 0, 0))
        continue
    ip, name, a = hops[h]
    best = a * random.uniform(0.8, 0.95)
    worst = a * random.uniform(1.05, 1.3) + (random.uniform(60, 90) if h == spike else 0)
    loss = "0.0%" if h != last else f"{random.choice([5.0, 10.0, 15.0])}%"
    lines.append(row(h, ip, loss, a * random.uniform(0.9, 1.1), a, best, worst, (worst - best) / 4))
open(f"{sb}/mtr-report.txt", "w").write("\n".join(lines) + "\n")
PY

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-9051  Payments: api.payprovider.example unreachable from app-07
---------------------------------------------------------------------
The ISP asks for two facts before they open a case:

  LAST_HOP  the address of the last hop on the path that still replies
  JUMP_HOP  the hop number where the latency first jumps by more than
            50 ms: compare each hop's Avg in mtr-report.txt with the Avg
            of the previous hop that answered

traceroute.txt is `traceroute api.payprovider.example` and
mtr-report.txt is `mtr -n --report -c 20 api.payprovider.example`,
both run from app-07 a minute apart. Put the answers in path.env as
LAST_HOP=... and JUMP_HOP=...
EOF
