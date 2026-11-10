#!/bin/bash
# $1 = sandbox path
# stor-04: two `ip -s -s link` captures 60 s apart and a grep of the
# /sys/class/net attributes. Random roles:
#   flapping  - one storage port: carrier transitions (transns) and CRC grow
#   halfdup   - one 1G port negotiated 100/half: collisions and window errors grow
#   oldnews   - the other storage port: huge CRC and transns, but no change
# eno2 is admin-down: speed -1 / duplex unknown / carrier "Invalid argument".
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import random

r = random.Random()
storage = ["ens1f0", "ens1f1"]
r.shuffle(storage)
flapping, oldnews = storage
halfdup = r.choice(["eno1", "ens2f0", "ens2f1"])
order = ["lo", "eno1", "eno2", "ens1f0", "ens1f1", "ens2f0", "ens2f1"]
alt = {"eno1": "enp4s0f0", "eno2": "enp4s0f1", "ens1f0": "enp65s0f0np0", "ens1f1": "enp65s0f1np1",
       "ens2f0": "enp66s0f0", "ens2f1": "enp66s0f1"}

def mac():
    return "b4:96:91:" + ":".join(f"{r.randrange(256):02x}" for _ in range(3))

info = {}
for i, n in enumerate(order, 1):
    d = {"idx": i, "mac": mac() if n != "lo" else "00:00:00:00:00:00"}
    big = n.startswith("ens1")
    d["rx_bytes"] = r.randrange(10**12, 9 * 10**12) if big else r.randrange(10**9, 9 * 10**10)
    d["rx_packets"] = d["rx_bytes"] // r.randrange(900, 1400)
    d["tx_bytes"] = r.randrange(10**12, 9 * 10**12) if big else r.randrange(10**9, 9 * 10**10)
    d["tx_packets"] = d["tx_bytes"] // r.randrange(900, 1400)
    d["mcast"] = r.randrange(100, 5000)
    for k in ("crc", "frame", "length", "fifo", "overrun", "missed", "rx_dropped", "tx_dropped",
              "collsns", "aborted", "window", "heartbt", "carrier"):
        d[k] = 0
    d["transns"] = r.choice([1, 2, 2, 4])
    d["speed"], d["duplex"], d["up"] = (25000 if big else 1000), "full", True
    d["rx_dropped"] = r.randrange(0, 40)
    info[n] = d
info["lo"].update(rx_bytes=88213440, rx_packets=611204, tx_bytes=88213440, tx_packets=611204, mcast=0,
                  rx_dropped=0, transns=0)
info["eno2"].update(rx_bytes=0, rx_packets=0, tx_bytes=0, tx_packets=0, mcast=0, rx_dropped=0, transns=0,
                    up=False, speed=-1, duplex="unknown")
info[oldnews].update(crc=r.randrange(30000, 90000), frame=r.randrange(200, 900), transns=r.randrange(250, 400))
info[flapping].update(crc=r.randrange(300, 2000), frame=r.randrange(5, 40), transns=r.randrange(9, 30) * 2)
info[halfdup].update(speed=100, duplex="half", collsns=r.randrange(5000, 20000), window=r.randrange(300, 900))

t0 = {n: dict(d) for n, d in info.items()}
t1 = {n: dict(d) for n, d in info.items()}
for n, d in t1.items():
    if n in ("lo", "eno2"):
        if n == "lo":
            d["rx_bytes"] += 52000; d["tx_bytes"] += 52000; d["rx_packets"] += 410; d["tx_packets"] += 410
        continue
    rate = 60 * (r.randrange(200, 900) * 10**6 if n.startswith("ens1") else r.randrange(2, 30) * 10**6)
    d["rx_bytes"] += rate; d["rx_packets"] += rate // 1100
    d["tx_bytes"] += rate // 2; d["tx_packets"] += rate // 2200
    d["mcast"] += r.randrange(0, 20)
t1[flapping]["transns"] += r.randrange(3, 7) * 2
t1[flapping]["crc"] += r.randrange(40, 600)
t1[flapping]["frame"] += r.randrange(1, 9)
t1[flapping]["rx_dropped"] += r.randrange(50, 300)
t1[halfdup]["collsns"] += r.randrange(200, 900)
t1[halfdup]["window"] += r.randrange(15, 80)

def table(prefix, labels, values, mins):
    widths = [max(m, len(str(v))) for m, v in zip(mins, values)]
    head = "    " + (prefix + labels[0].rjust(widths[0] - len(prefix))) + "".join(
        " " + l.rjust(w) for l, w in zip(labels[1:], widths[1:]))
    vals = "    " + "".join((" " if i else "") + str(v).rjust(w) for i, (v, w) in enumerate(zip(values, widths)))
    return head + "\n" + vals + " \n"

def dump(snap):
    out = []
    for n in order:
        d = snap[n]
        if n == "lo":
            out.append(f"1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000\n"
                       f"    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00\n")
        elif d["up"]:
            mtu = 9000 if n.startswith("ens1") else 1500
            out.append(f"{d['idx']}: {n}: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu {mtu} qdisc mq state UP mode DEFAULT group default qlen 1000\n"
                       f"    link/ether {d['mac']} brd ff:ff:ff:ff:ff:ff\n")
        else:
            out.append(f"{d['idx']}: {n}: <BROADCAST,MULTICAST> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000\n"
                       f"    link/ether {d['mac']} brd ff:ff:ff:ff:ff:ff\n")
        rx_err = d["crc"] + d["frame"] + d["length"] + d["fifo"] + d["overrun"]
        tx_err = d["aborted"] + d["window"] + d["heartbt"] + d["carrier"]
        out.append(table("RX: ", ["bytes", "packets", "errors", "dropped", "missed", "mcast"],
                         [d["rx_bytes"], d["rx_packets"], rx_err, d["rx_dropped"], d["missed"], d["mcast"]],
                         [10, 7, 6, 7, 7, 7]))
        out.append(table("RX errors: ", ["length", "crc", "frame", "fifo", "overrun"],
                         [d["length"], d["crc"], d["frame"], d["fifo"], d["overrun"]], [18, 6, 7, 7, 7]))
        out.append(table("TX: ", ["bytes", "packets", "errors", "dropped", "carrier", "collsns"],
                         [d["tx_bytes"], d["tx_packets"], tx_err, d["tx_dropped"], d["carrier"], d["collsns"]],
                         [10, 7, 6, 7, 7, 7]))
        out.append(table("TX errors: ", ["aborted", "fifo", "window", "heartbt", "transns"],
                         [d["aborted"], d["fifo"], d["window"], d["heartbt"], d["transns"]], [18, 6, 7, 7, 7]))
        if n in alt:
            out.append(f"    altname {alt[n]}\n")
    return "".join(out)

with open("ip-link-1402.txt", "w") as f:
    f.write("stor-04$ date; ip -s -s link\nTue Nov 10 14:02:07 UTC 2026\n" + dump(t0))
with open("ip-link-1403.txt", "w") as f:
    f.write("stor-04$ date; ip -s -s link\nTue Nov 10 14:03:07 UTC 2026\n" + dump(t1))

lines = ["stor-04$ grep -H . /sys/class/net/*/{operstate,carrier,carrier_changes,speed,duplex,mtu}"]
for attr in ("operstate", "carrier", "carrier_changes", "speed", "duplex", "mtu"):
    for n in order:
        d = t1[n]
        p = f"/sys/class/net/{n}/{attr}"
        if attr == "operstate":
            v = "unknown" if n == "lo" else ("up" if d["up"] else "down")
        elif attr == "carrier":
            v = "1" if d["up"] else None
        elif attr == "carrier_changes":
            v = str(d["transns"])
        elif attr == "speed":
            v = None if n == "lo" else str(d["speed"])
        elif attr == "duplex":
            v = None if n == "lo" else d["duplex"]
        else:
            v = "65536" if n == "lo" else ("9000" if n.startswith("ens1") else "1500")
        lines.append(f"grep: {p}: Invalid argument" if v is None else f"{p}:{v}")
with open("sysfs-net.txt", "w") as f:
    f.write("\n".join(lines) + "\n")
PY

cat > TICKET.txt <<'EOF'
STOR-882  stor-04 drops client connections

Clients of stor-04 see their NFS/iSCSI sessions drop and reconnect every few
minutes, and the backup job over the 1G network crawls. Monitoring only
graphs totals, which look "high everywhere".

Attached: two `ip -s -s link` captures taken 60 seconds apart
(ip-link-1402.txt, ip-link-1403.txt) and the /sys/class/net attributes,
grabbed right after the second capture (sysfs-net.txt).

Wanted in link.env:
FLAPPING=<interface whose link keeps going down and up>
DUPLEX_MISMATCH=<interface running at the wrong duplex>
CRC_DELTA=<how many CRC errors the flapping interface got in those 60 s>
EOF
