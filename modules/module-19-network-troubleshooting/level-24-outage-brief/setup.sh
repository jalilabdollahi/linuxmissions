#!/bin/bash
# $1 = sandbox path
# Checkout -> payments outage with four faults at once (Linux: uses several
# 127.0.20.x loopback addresses):
#   1. proxy: client.env sends everything through the proxy; the proxy can't
#      reach corp hosts and hangs, so every backend call times out and hides
#      the rest
#   2. port: payments moved from 8080 to a random port, published as an SRV
#      record; client.env still says 8080 (connection refused)
#   3. hosts: etc/hosts pins one backend to its old address (refused)
#   4. one backend answers 503 to everything, but still listens
# The live DNS server has the truth. logs/checkout.log and changes.log are
# the evidence for brief.md (first/last failed payments call, how many).
SANDBOX="$1"
NET="$SANDBOX/.net"
mkdir -p "$NET" "$SANDBOX/etc" "$SANDBOX/bin" "$SANDBOX/checkout" "$SANDBOX/logs"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/dns_server.py" "$MOCKS/http_server.py" "$NET/"
cd "$SANDBOX" || exit 1

mapfile -t order < <(printf '1\n2\n3\n' | shuf)
sick=${order[0]} moved=${order[1]}          # 503 backend, backend with a stale hosts entry
newport=$(( RANDOM % 20000 + 20000 ))
echo "$sick $moved $newport" > "$NET/faults"

# --- payments backends: same new port, one loopback address each ----------
for n in 1 2 3; do
  if [ "$n" = "$sick" ]; then
    printf '{"server": "payments/4.1.0", "routes": [{"path": "/*", "status": 503, "json": {"status": "unavailable", "reason": "storage degraded"}, "headers": {"Retry-After": "120"}}]}\n' > "$NET/pay-$n.json"
  else
    printf '{"server": "payments/4.1.0", "routes": [{"path": "/v1/health", "json": {"status": "ok", "node": "pay-%s"}}, {"path": "/*", "json": {"ok": true}}]}\n' "$n" > "$NET/pay-$n.json"
  fi
  python3 "$NET/http_server.py" --config "$NET/pay-$n.json" --host "127.0.20.1$n" --port "$newport" \
    --log "$NET/pay-$n.log" --port-file "$NET/pay-$n.port" --idle-timeout 0 --daemon \
    || { echo "could not start payments backend pay-$n" >&2; exit 1; }
done

# --- the proxy: vendor sites only; corp hosts hang (it can't reach them) ---
cat > "$NET/proxy.json" <<'EOF'
{"server": "squid/6.6", "routes": [
  {"path": "/*", "host": "fx.vendor.example", "json": {"base": "EUR", "USD": 1.0712, "GBP": 0.8423}},
  {"path": "/*", "hang": true}
]}
EOF
python3 "$NET/http_server.py" --config "$NET/proxy.json" --log "$NET/proxy.log" \
  --port-file "$NET/proxy.port" --idle-timeout 0 --daemon \
  || { echo "could not start the proxy" >&2; exit 1; }
proxy=$(cat "$NET/proxy.port")

# --- DNS -------------------------------------------------------------------
cat > "$NET/corp.zone" <<EOF
\$ORIGIN corp.example.
\$TTL 300
@          IN SOA ns1 hostmaster ( 2026111009 3600 600 86400 300 )
@             NS    ns1
ns1           A     127.0.0.53
pay-1         A     127.0.20.11
pay-2         A     127.0.20.12
pay-3         A     127.0.20.13
_payments._tcp SRV  10 50 $newport pay-1
_payments._tcp SRV  10 50 $newport pay-2
_payments._tcp SRV  10 50 $newport pay-3
ledger        A     127.0.20.40
checkout      A     127.0.20.5
EOF
python3 "$NET/dns_server.py" --zone "$NET/corp.zone" --log "$NET/dns.log" \
  --port-file "$NET/dns.port" --idle-timeout 0 --daemon \
  || { echo "could not start the DNS server" >&2; exit 1; }
dns=$(cat "$NET/dns.port")

# --- app-31's files ---------------------------------------------------------
cat > etc/hosts <<EOF
127.0.0.1	localhost
127.0.1.1	app-31.corp.example	app-31
::1	ip6-localhost ip6-loopback

# pinned during the 2025 DC move (ops)
127.0.20.40	ledger.corp.example ledger
127.0.19.1$moved	pay-$moved.corp.example pay-$moved
127.0.20.5	checkout.corp.example checkout
EOF
cp etc/hosts "$NET/hosts.orig"

cat > checkout/client.env <<EOF
# checkout -> payments client settings (loaded by the checkout service and by smoke.sh)
export http_proxy=http://127.0.0.1:$proxy
export https_proxy=http://127.0.0.1:$proxy
export no_proxy=localhost,127.0.0.1
PAYMENTS_PORT=8080
PAYMENTS_BACKENDS="pay-1.corp.example pay-2.corp.example pay-3.corp.example"
FX_URL=http://fx.vendor.example/v1/rates
EOF

cat > bin/getent <<'PY'
#!/usr/bin/env python3
"""getent hosts NAME - app-31's resolver: etc/hosts first, then the lab DNS
server (127.0.0.1, port in .net/dns.port)."""
import os, random, socket, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def files(name):
    for line in open(os.path.join(ROOT, "etc/hosts"), errors="replace"):
        w = line.split("#")[0].split()
        if len(w) > 1 and ":" not in w[0] and name.lower() in map(str.lower, w[1:]):
            return f"{w[0]:<15} {' '.join(w[1:])}"

def dns(name):
    port = int(open(os.path.join(ROOT, ".net/dns.port")).read())
    q = struct.pack(">HHHHHH", random.randrange(65536), 0x0100, 1, 0, 0, 0)
    q += b"".join(bytes([len(p)]) + p.encode() for p in name.rstrip(".").split(".")) + b"\0\0\1\0\1"
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(3)
    try:
        s.sendto(q, ("127.0.0.1", port))
        r = s.recv(4096)
    except OSError:
        return None
    if r[3] & 15:
        return None
    i = 12
    while r[i]:
        i += r[i] + 1
    i += 5
    for _ in range(struct.unpack(">H", r[6:8])[0]):
        while r[i] and r[i] < 0xC0:
            i += r[i] + 1
        i += 2 if r[i] >= 0xC0 else 1
        t, _, _, ln = struct.unpack(">HHIH", r[i:i + 10])
        i += 10
        if t == 1:
            return f"{socket.inet_ntoa(r[i:i + ln]):<15} {name}"
        i += ln

if len(sys.argv) < 3 or sys.argv[1] != "hosts":
    print("usage: getent hosts NAME...", file=sys.stderr)
    sys.exit(1)
rc = 0
for n in sys.argv[2:]:
    ans = files(n) or dns(n)
    print(ans) if ans else None
    rc = rc if ans else 2
sys.exit(rc)
PY
chmod +x bin/getent
cp bin/getent "$NET/getent.orig"

cat > smoke.sh <<'EOF'
#!/bin/bash
# checkout's smoke test: every payments backend's /v1/health and the FX
# rates, exactly the way the checkout service calls them.
cd "$(dirname "$0")" || exit 1
. checkout/client.env
fail=0 n=0
for b in $PAYMENTS_BACKENDS; do
  n=$((n + 1))
  ip=$(bin/getent hosts "$b" | awk '{ print $1 }')
  if [ -z "$ip" ]; then echo "FAIL  $b: name does not resolve"; fail=1; continue; fi
  out=$(curl -s --max-time 4 -o /dev/null -w '%{http_code} %{errormsg}' --resolve "$b:$PAYMENTS_PORT:$ip" \
        "http://$b:$PAYMENTS_PORT/v1/health")
  case $out in
    200*) echo "OK    $b:$PAYMENTS_PORT ($ip)" ;;
    000*) echo "FAIL  $b:$PAYMENTS_PORT ($ip): ${out#000 }"; fail=1 ;;
    *)    echo "FAIL  $b:$PAYMENTS_PORT ($ip): HTTP ${out%% *}"; fail=1 ;;
  esac
done
[ "$n" -ge 2 ] || { echo "FAIL  checkout needs at least two payments backends"; fail=1; }
out=$(curl -s --max-time 4 -o /dev/null -w '%{http_code} %{errormsg}' "$FX_URL")
case $out in
  200*) echo "OK    $FX_URL" ;;
  000*) echo "FAIL  $FX_URL: ${out#000 }"; fail=1 ;;
  *)    echo "FAIL  $FX_URL: HTTP ${out%% *}"; fail=1 ;;
esac
[ $fail -eq 0 ] && echo "smoke test passed" || echo "smoke test FAILED"
exit $fail
EOF
chmod +x smoke.sh
cp smoke.sh "$NET/smoke.orig"

# --- evidence: change log and checkout's log --------------------------------
python3 - "$sick" "$moved" "$newport" <<'PY'
import random, sys
from datetime import datetime, timedelta

sick, moved, newport = sys.argv[1], sys.argv[2], sys.argv[3]
r = random.Random()
t0 = datetime(2026, 11, 10, 8, 30, 0)
chg_port = t0 + timedelta(minutes=r.randrange(25, 50), seconds=r.randrange(60))
chg_ip = chg_port + timedelta(minutes=r.randrange(2, 5))
chg_proxy = chg_ip + timedelta(minutes=r.randrange(4, 9))
declared = chg_proxy + timedelta(minutes=r.randrange(25, 55))

with open("changes.log", "w") as f:
    f.write(f"{chg_port:%Y-%m-%d %H:%M} CHG-7001 payments: listeners moved from :8080 to the new port on pay-1..3, "
            f"published as SRV _payments._tcp.corp.example (team payments)\n")
    f.write(f"{chg_ip:%Y-%m-%d %H:%M} CHG-7002 pay-{moved} renumbered 127.0.19.1{moved} -> 127.0.20.1{moved}, DNS updated (team network)\n")
    f.write(f"{chg_proxy:%Y-%m-%d %H:%M} CHG-7005 proxy settings rolled out to all app hosts from the standard template (team platform)\n")
    f.write(f"{declared:%Y-%m-%d %H:%M} INC-4410 declared: checkout can't reach payments\n")

lines = []
t = t0
while t < declared:
    t += timedelta(seconds=r.randrange(20, 70))
    if t >= declared:
        break
    ts = f"{t:%Y-%m-%dT%H:%M:%SZ}"
    b = r.choice("123")
    if r.random() < 0.12:
        lines.append(f'{ts} ERROR inventory call failed sku={r.randrange(10000, 99999)} err="HTTP 500"')
        continue
    if t < chg_port:
        if r.random() < 0.15:
            lines.append(f"{ts} WARN payments call slow backend=pay-{b}.corp.example ms={r.randrange(900, 1800)}")
        else:
            lines.append(f"{ts} INFO payments call ok backend=pay-{b}.corp.example ms={r.randrange(30, 120)}")
        continue
    if t < chg_proxy:
        err = "connect: connection refused"
    else:
        err = "timeout after 4000ms"
    lines.append(f'{ts} ERROR payments call failed backend=pay-{b}.corp.example order={r.randrange(10**6, 10**7)} err="{err}"')
    if r.random() < 0.5:
        lines.append(f"{ts} WARN payments retry 1/1 order pending")
with open("logs/checkout.log", "w") as f:
    f.write("\n".join(lines) + "\n")
PY

cat > brief.md <<'EOF'
# Outage brief: checkout -> payments (INC-4410)

Fill in every field (one line each). Times exactly as written in
logs/checkout.log.

impact_start:
impact_end:
failed_calls:
new_port:
removed_backend:
root_cause:
fix:
EOF

cat > TICKET.txt <<EOF
INC-4410  Checkout can't reach the payments API

Since this morning every payment in checkout fails. You're on app-31, the
checkout host (this sandbox has its etc/hosts, checkout/client.env, logs/
and the change log). ./smoke.sh runs the checks the checkout service does.
The lab's DNS server is 127.0.0.1 port $dns and has the current records
for corp.example; \`getent\` on your PATH resolves the way app-31 does.

1. Get checkout working again: fix app-31's configuration (client.env,
   etc/hosts) until ./smoke.sh passes. Don't touch the payments servers;
   if a backend is unhealthy, take it out of checkout's backend list.
2. Fill in brief.md from the evidence: impact_start and impact_end are the
   times of the first and last failed payments call in logs/checkout.log,
   failed_calls is how many failed payments calls it logged, new_port and
   removed_backend are what you found, root_cause names the change that
   started the outage, and fix says in one line what you changed.
EOF
