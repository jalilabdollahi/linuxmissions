#!/bin/bash
# Writes capture.pcap: a real libpcap file (Ethernet/IPv4/TCP/UDP) recorded on
# web-03 (10.20.4.17). Reading a saved capture with `tcpdump -r` needs no root.
#
# What is in it (the answer is fixed, the generator is deterministic):
#   - 203.0.113.66 SYN-scans 45 ports; 22, 80, 443, 8080 and 9100 answer
#     SYN-ACK, the rest answer RST.
#   - 198.51.100.23 opens 60 connections to SSH (more SYNs than the scanner,
#     but always the same port).
#   - normal HTTPS clients, an admin SSH session, DNS lookups by web-03, and
#     web-03's own connections to its database.
SANDBOX="$1"

python3 - "$SANDBOX/capture.pcap" <<'PY'
import random, struct, sys

out = sys.argv[1]
rng = random.Random(4471)
SERVER = "10.20.4.17"
MAC_SRV = bytes.fromhex("3cecef129a41")
MAC_GW = bytes.fromhex("001b21aabb01")
LAN = {"10.20.4.2", "10.20.4.30", "10.20.4.101"}
MACS = {"10.20.4.2": bytes.fromhex("525400a1b202"), "10.20.4.30": bytes.fromhex("525400a1b21e"),
        "10.20.4.101": bytes.fromhex("f4ce46b70c65")}
packets = []          # (time, frame bytes)
ip_id = [1000]

def ip4(a):
    return bytes(int(x) for x in a.split("."))

def csum(data):
    if len(data) % 2:
        data += b"\0"
    s = sum(struct.unpack("!%dH" % (len(data) // 2), data))
    while s >> 16:
        s = (s & 0xFFFF) + (s >> 16)
    return ~s & 0xFFFF

def frame(src, dst, proto, l4):
    ip_id[0] = (ip_id[0] + rng.randint(1, 9)) & 0xFFFF
    ttl = 64 if src == SERVER or src in LAN else 52
    hdr = struct.pack("!BBHHHBBH4s4s", 0x45, 0, 20 + len(l4), ip_id[0], 0x4000, ttl, proto, 0, ip4(src), ip4(dst))
    hdr = hdr[:10] + struct.pack("!H", csum(hdr)) + hdr[12:]
    smac = MAC_SRV if src == SERVER else MACS.get(src, MAC_GW)
    dmac = MAC_SRV if dst == SERVER else MACS.get(dst, MAC_GW)
    return dmac + smac + b"\x08\x00" + hdr + l4

FLAGS = {"S": 0x02, "SA": 0x12, "A": 0x10, "PA": 0x18, "FA": 0x11, "R": 0x04, "RA": 0x14}

def tcp(t, src, sport, dst, dport, flags, seq, ack=0, payload=b"", win=64240, mss=True):
    opts = b""
    if flags in ("S", "SA") and mss:
        opts = struct.pack("!BBH", 2, 4, 1460)
    off = (20 + len(opts)) // 4
    seg = struct.pack("!HHIIBBHHH", sport, dport, seq & 0xFFFFFFFF, ack & 0xFFFFFFFF,
                      off << 4, FLAGS[flags], win, 0, 0) + opts + payload
    pseudo = ip4(src) + ip4(dst) + struct.pack("!BBH", 0, 6, len(seg))
    seg = seg[:16] + struct.pack("!H", csum(pseudo + seg)) + seg[18:]
    packets.append((t, frame(src, dst, 6, seg)))

def udp(t, src, sport, dst, dport, payload):
    seg = struct.pack("!HHHH", sport, dport, 8 + len(payload), 0) + payload
    packets.append((t, frame(src, dst, 17, seg)))

def qname(name):
    return b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\0"

def dns(t, qid, name, answers):
    sport = rng.randint(33000, 60999)
    q = struct.pack("!HHHHHH", qid, 0x0100, 1, 0, 0, 1) + qname(name) + struct.pack("!HH", 1, 1) \
        + b"\x00\x00\x29\x04\xd0\x00\x00\x00\x00\x00\x00"
    udp(t, SERVER, sport, "10.20.4.2", 53, q)
    r = struct.pack("!HHHHHH", qid, 0x8180, 1, len(answers), 0, 0) + qname(name) + struct.pack("!HH", 1, 1)
    for a in answers:
        r += b"\xc0\x0c" + struct.pack("!HHIH", 1, 1, 60, 4) + ip4(a)
    udp(t + 0.0012, "10.20.4.2", 53, SERVER, sport, r)

def session(t, client, sport, port, req, resp):
    """A complete, polite TCP connection from client to SERVER:port."""
    c, s = rng.randint(1, 2**31), rng.randint(1, 2**31)
    rtt = rng.uniform(0.004, 0.03)
    tcp(t, client, sport, SERVER, port, "S", c)
    tcp(t + 0.00005, SERVER, port, client, sport, "SA", s, c + 1, win=65160)
    tcp(t + rtt, client, sport, SERVER, port, "A", c + 1, s + 1)
    tcp(t + rtt + 0.0002, client, sport, SERVER, port, "PA", c + 1, s + 1, b"\x16" * req)
    tcp(t + rtt + 0.0004, SERVER, port, client, sport, "PA", s + 1, c + 1 + req, b"\x17" * resp, win=65160)
    tcp(t + 2 * rtt + 0.0005, client, sport, SERVER, port, "FA", c + 1 + req, s + 1 + resp)
    tcp(t + 2 * rtt + 0.0006, SERVER, port, client, sport, "FA", s + 1 + resp, c + 2 + req, win=65160)
    tcp(t + 3 * rtt + 0.0007, client, sport, SERVER, port, "A", c + 2 + req, s + 2 + resp)

T0 = 1793269200.0      # 2026-10-29 10:20:00 UTC

# Normal HTTPS traffic all along.
clients = ["198.51.100.%d" % n for n in (12, 40, 77, 91, 140)] + ["192.0.2.%d" % n for n in (8, 33, 54, 120, 201)] + \
          ["100.64.3.%d" % n for n in (17, 44, 90)]
for i in range(26):
    session(T0 + i * 1.13 + rng.random(), rng.choice(clients), rng.randint(40000, 60999), 443,
            rng.randint(200, 700), rng.randint(900, 1400))

# Admin SSH session that was already open when the capture started.
c, s = 88123001, 51234411
for i in range(30):
    t = T0 + 0.7 + i * 0.97
    tcp(t, "10.20.4.101", 50122, SERVER, 22, "PA", c, s, b"\x00" * 36)
    tcp(t + 0.0003, SERVER, 22, "10.20.4.101", 50122, "PA", s, c + 36, b"\x00" * 92, win=501)
    c += 36; s += 92

# SSH password guessing: 60 connections to port 22, each reset after the banner.
for i in range(60):
    t = T0 + 3.0 + i * 0.4 + rng.random() * 0.2
    sport = 35000 + i * 7
    cs, ss = rng.randint(1, 2**31), rng.randint(1, 2**31)
    tcp(t, "198.51.100.23", sport, SERVER, 22, "S", cs, win=29200)
    tcp(t + 0.0001, SERVER, 22, "198.51.100.23", sport, "SA", ss, cs + 1, win=65160)
    tcp(t + 0.041, "198.51.100.23", sport, SERVER, 22, "A", cs + 1, ss + 1, win=29200)
    tcp(t + 0.052, SERVER, 22, "198.51.100.23", sport, "PA", ss + 1, cs + 1, b"SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.5\r\n", win=65160)
    tcp(t + 0.31, "198.51.100.23", sport, SERVER, 22, "RA", cs + 1, ss + 44, win=0)

# The SYN scan: one source port, small window, 45 ports in random order.
OPEN = {22, 80, 443, 8080, 9100}
ports = [21, 22, 23, 25, 53, 80, 110, 111, 135, 139, 143, 389, 443, 445, 465, 587, 631, 993, 995,
         1433, 1521, 2049, 2375, 3000, 3306, 3389, 4444, 5000, 5432, 5900, 6379, 6443, 8000, 8008,
         8080, 8081, 8443, 8888, 9000, 9090, 9100, 9200, 10250, 11211, 27017]
rng.shuffle(ports)
for i, port in enumerate(ports):
    t = T0 + 9.5 + i * 0.013 + rng.random() * 0.004
    seq = rng.randint(1, 2**31)
    tcp(t, "203.0.113.66", 41922, SERVER, port, "S", seq, win=1024)
    if port in OPEN:
        tcp(t + 0.00004, SERVER, port, "203.0.113.66", 41922, "SA", rng.randint(1, 2**31), seq + 1, win=64240)
        tcp(t + 0.0381, "203.0.113.66", 41922, SERVER, port, "R", seq + 1, win=0, mss=False)
    else:
        tcp(t + 0.00003, SERVER, port, "203.0.113.66", 41922, "RA", 0, seq + 1, win=0, mss=False)

# web-03 talks to its database and resolves names.
for i in range(6):
    session_t = T0 + 2.2 + i * 4.1
    sport = 46100 + i
    cs, ss = rng.randint(1, 2**31), rng.randint(1, 2**31)
    tcp(session_t, SERVER, sport, "10.20.4.30", 5432, "S", cs)
    tcp(session_t + 0.0002, "10.20.4.30", 5432, SERVER, sport, "SA", ss, cs + 1, win=65160)
    tcp(session_t + 0.0003, SERVER, sport, "10.20.4.30", 5432, "A", cs + 1, ss + 1)
for i, (name, ans) in enumerate([("db.internal", ["10.20.4.30"]), ("api.stripe.com", ["198.18.7.51", "198.18.7.52"]),
                                 ("db.internal", ["10.20.4.30"]), ("cdn.example.net", ["192.0.2.180"])]):
    dns(T0 + 1.9 + i * 6.3, 0x2A10 + i * 97, name, ans)

packets.sort(key=lambda p: p[0])
with open(out, "wb") as f:
    f.write(struct.pack("<IHHiIII", 0xA1B2C3D4, 2, 4, 0, 0, 262144, 1))
    for t, data in packets:
        sec = int(t)
        usec = int(round((t - sec) * 1e6))
        if usec >= 1000000:
            sec, usec = sec + 1, usec - 1000000
        f.write(struct.pack("<IIII", sec, usec, len(data), len(data)))
        f.write(data)
PY
