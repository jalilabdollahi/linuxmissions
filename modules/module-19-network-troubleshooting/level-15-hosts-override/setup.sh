#!/bin/bash
# $1 = sandbox path
# app-07 after a DB failover: DNS (the shared mock, live on loopback) has the
# new primary, but etc/hosts carries db.corp.example as an ALIAS on the old
# primary's line (now the reports DB). nsswitch says "files dns", so the
# alias wins. reports-db exists only on that line (not in DNS), so deleting
# the whole line breaks it. A colleague's "fix" added a correct line at the bottom, which
# never matches because the first matching line wins. Decoys: a commented
# old line and metricsdb.corp.example (a substring match for a careless grep).
# bin/getent implements `getent hosts` over the sandbox's etc/ files and the
# mock DNS server.
SANDBOX="$1"
NET="$SANDBOX/.net"
mkdir -p "$NET" "$SANDBOX/etc" "$SANDBOX/bin"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/dns_server.py" "$NET/"
cd "$SANDBOX" || exit 1

old="10.40.1.$(( RANDOM % 80 + 10 ))"
new="10.40.2.$(( RANDOM % 80 + 100 ))"
git_dns="10.40.5.$(( RANDOM % 50 + 10 ))"
git_override="10.40.6.$(( RANDOM % 50 + 10 ))"

cat > "$NET/corp.zone" <<EOF
\$ORIGIN corp.example.
\$TTL 300
@          IN SOA ns1 hostmaster ( 2026111003 3600 600 86400 300 )
@             NS    ns1
ns1           A     10.40.0.2
db            A     $new
db-a          A     $old
db-b          A     $new
metricsdb     A     10.40.7.4
git           A     $git_dns
www           A     10.40.3.10
mail          A     10.40.3.25
app-07        A     10.40.4.7
cache         A     10.40.4.30
EOF
python3 "$NET/dns_server.py" --zone "$NET/corp.zone" --log "$NET/query.log" \
  --port-file "$NET/dns.port" --idle-timeout 0 --daemon \
  || { echo "could not start the DNS server" >&2; exit 1; }
PORT=$(cat "$NET/dns.port")

cat > etc/nsswitch.conf <<'EOF'
# /etc/nsswitch.conf
#
# Example configuration of GNU Name Service Switch functionality.
# If you have the `glibc-doc-reference' and `info' packages installed, try:
# `info libc "Name Service Switch"' for information about this file.

passwd:         files systemd
group:          files systemd
shadow:         files
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOF

# A random number of harmless lines before the stale one, so the line
# number is different every time.
{
  printf '127.0.0.1\tlocalhost\n127.0.1.1\tapp-07.corp.example\tapp-07\n\n'
  printf '# The following lines are desirable for IPv6 capable hosts\n'
  printf '::1     ip6-localhost ip6-loopback\nfe00::0 ip6-localnet\nff00::0 ip6-mcastprefix\n'
  printf 'ff02::1 ip6-allnodes\nff02::2 ip6-allrouters\n\n'
  printf '# --- managed overrides (ops) ---\n'
  extras=("10.40.9.$(( RANDOM % 50 + 2 ))  legacy-api.corp.example legacy-api   # not in DNS, retired 2027"
          "$git_override  git.corp.example git           # pinned to the git mirror during CHG-4410"
          "10.40.7.4   metricsdb.corp.example metricsdb"
          "10.40.4.30  cache.corp.example cache"
          "10.40.8.$(( RANDOM % 50 + 2 ))  ldap.corp.example ldap         # not in DNS"
          "10.40.3.25  mail.corp.example mail")
  n=$(( RANDOM % 4 + 2 ))
  for e in "${extras[@]:0:$n}"; do echo "$e"; done
  printf '# %s  db.corp.example   # old primary, see CHG-5521\n' "$old"
  printf '%s\tdb-a.corp.example db-a reports-db.corp.example db.corp.example\n' "$old"
  for e in "${extras[@]:$n}"; do echo "$e"; done
  printf '\n# CHG-5521 failover: new primary (added by mk, 03:12)\n%s\tdb.corp.example\n' "$new"
} > etc/hosts
cp etc/hosts "$NET/hosts.orig"
cp etc/nsswitch.conf "$NET/nsswitch.orig"

cat > bin/getent <<'PY'
#!/usr/bin/env python3
"""getent hosts [NAME...] for this lab: follows etc/nsswitch.conf ("hosts:"),
reads etc/hosts and asks the lab's DNS server (127.0.0.1, port in .net/dns.port)."""
import os, random, socket, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def hosts_lines():
    out = []
    for line in open(os.path.join(ROOT, "etc/hosts"), encoding="utf-8", errors="replace"):
        f = line.split("#", 1)[0].split()
        if len(f) >= 2:
            out.append(f)
    return out

def src_files(name):
    for f in hosts_lines():
        if ":" in f[0]:
            continue                        # IPv6 entries: this getent asks for IPv4
        if name.lower() in (n.lower() for n in f[1:]):
            return [" ".join([f"{f[0]:<15}"] + f[1:])]
    return None

def src_dns(name):
    try:
        port = int(open(os.path.join(ROOT, ".net/dns.port")).read())
    except (OSError, ValueError):
        return "unavail"
    qid = random.randrange(65536)
    q = struct.pack(">HHHHHH", qid, 0x0100, 1, 0, 0, 0)
    q += b"".join(bytes([len(p)]) + p.encode() for p in name.rstrip(".").split(".")) + b"\0" + struct.pack(">HH", 1, 1)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(3)
    try:
        s.sendto(q, ("127.0.0.1", port))
        data = s.recv(4096)
    except OSError:
        return "unavail"
    rcode, an = data[3] & 15, struct.unpack(">H", data[6:8])[0]
    if rcode == 3:
        return None
    if rcode != 0:
        return "unavail"
    i = 12
    while data[i]:
        i += data[i] + 1
    i += 5
    addrs = []
    for _ in range(an):
        while True:                         # skip the (possibly compressed) owner name
            if data[i] >= 0xC0:
                i += 2
                break
            if data[i] == 0:
                i += 1
                break
            i += data[i] + 1
        rtype, _, _, rdlen = struct.unpack(">HHIH", data[i:i + 10])
        i += 10
        if rtype == 1:
            addrs.append(socket.inet_ntoa(data[i:i + rdlen]))
        i += rdlen
    if not addrs:
        return None
    return [f"{a:<15} {name}" for a in addrs]

def sources():
    for line in open(os.path.join(ROOT, "etc/nsswitch.conf")):
        line = line.split("#", 1)[0]
        if line.strip().startswith("hosts:"):
            return line.split(":", 1)[1].split()
    return ["files", "dns"]

def lookup(name):
    status = None
    for item in sources():
        if item.startswith("["):
            for cond in item.strip("[]").split():
                k, _, v = cond.partition("=")
                if k.lower() == (status or "").lower() and v.lower() == "return":
                    return None
            continue
        if item == "files":
            res = src_files(name)
        elif item == "dns":
            res = src_dns(name)
        elif item == "myhostname":
            res = [f"{'127.0.0.1':<15} localhost"] if name.lower() == "localhost" else None
        else:
            res = "unavail"
        if res and res != "unavail":
            return res
        status = "unavail" if res == "unavail" else "notfound"
    return None

args = sys.argv[1:]
if not args or args[0] != "hosts":
    print("usage: getent hosts [NAME...]   (this lab's getent only knows the hosts database)", file=sys.stderr)
    sys.exit(1)
if len(args) == 1:
    for f in hosts_lines():
        print(" ".join([f"{f[0]:<15}"] + f[1:]))
    sys.exit(0)
rc = 0
for name in args[1:]:
    res = lookup(name)
    if res:
        print(res[0])
    else:
        rc = 2
sys.exit(rc)
PY
chmod +x bin/getent
cp bin/getent "$NET/getent.orig"

cat > TICKET.txt <<EOF
DB-1187  app-07 still talks to the old database

Last night the database failed over: the new primary for db.corp.example is
db-b, and DNS was updated right away (the lab's DNS server is 127.0.0.1,
port $PORT). Every app server picked it up except app-07, which still
connects to the old primary (db-a, now the reports database). Restarting the
app didn't help, and mk's attempt at 03:12 didn't either.

This sandbox is a copy of app-07's etc/. The app resolves names the normal
way (like \`getent hosts NAME\`; a copy that reads this sandbox's etc/ files
and the lab DNS is on your PATH).

1. Fix it on app-07 so db.corp.example gets the new primary. Every other
   name must keep resolving exactly as before (some overrides are there on
   purpose).
2. Write cause.txt with the file and line number of the entry that was
   responsible, as FILE:LINE (for example etc/hosts:3), counting lines in
   the file as you found it.
EOF
