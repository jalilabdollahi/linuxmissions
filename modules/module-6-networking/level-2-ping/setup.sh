#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/hosts.txt" <<'EOF'
# hosts.txt - inventory export from the CMDB, 2026-11-10
web-1
web-2
db-1
db-2

cache-1
backup-1
mon-1
lb-1
old-ftp
EOF

# Simulated network: name, address, and whether the host answers.
mkdir -p "$SANDBOX/.netsim"
cat > "$SANDBOX/.netsim/hosts" <<'EOF'
web-1    10.20.4.21  up
web-2    10.20.4.22  up
db-1     10.20.4.31  down
db-2     10.20.4.32  up
cache-1  10.20.4.41  up
backup-1 10.20.4.51  down
mon-1    10.20.4.61  up
lb-1     10.20.4.11  up
EOF
: > "$SANDBOX/.netsim/ping.log"

# ./ping - stand-in for ping(8). The sandbox has no network, so this script
# answers from .netsim/hosts, with the same output and exit codes as
# iputils ping: 0 = got a reply, 1 = no reply, 2 = name does not resolve.
cat > "$SANDBOX/ping" <<'MOCK'
#!/bin/bash
here="$(cd "$(dirname "$0")" && pwd)"
count="" quiet="" host=""
while [ $# -gt 0 ]; do
  case "$1" in
    -c)      count="$2"; shift 2 ;;
    -c*)     count="${1#-c}"; shift ;;
    -W|-w|-i|-s|-t|-I) shift 2 ;;
    -q)      quiet=1; shift ;;
    -[46nvD]) shift ;;
    -h|--help)
      echo "Usage: ping [-c count] [-W timeout] [-q] <destination>  (LinuxMissions stand-in)"; exit 0 ;;
    -*)      echo "ping: invalid option -- '${1#-}'" >&2; exit 2 ;;
    *)       host="$1"; shift ;;
  esac
done
if [ -z "$host" ]; then
  echo "ping: usage error: Destination address required" >&2
  exit 1
fi
case "$count" in ''|*[!0-9]*) [ -n "$count" ] && { echo "ping: invalid argument: '$count'" >&2; exit 1; } ;; esac
echo "$host" >> "$here/.netsim/ping.log"

line="$(awk -v h="$host" '$1 == h || $2 == h' "$here/.netsim/hosts")"
if [ -z "$line" ]; then
  echo "ping: $host: Name or service not known" >&2
  exit 2
fi
set -- $line
name="$1" ip="$2" state="$3"
[ "$host" = "$ip" ] && name="$ip"

forever=""
if [ -z "$count" ]; then count=4; forever=1; fi
[ "$count" -gt 10 ] && count=10

echo "PING $host ($ip) 56(84) bytes of data."
received=0
times=""
for ((seq = 1; seq <= count; seq++)); do
  if [ "$state" = "up" ]; then
    t="0.$(( (RANDOM % 600) + 200 ))"
    times="$times $t"
    received=$((received + 1))
    [ -z "$quiet" ] && echo "64 bytes from $name ($ip): icmp_seq=$seq ttl=64 time=$t ms"
  fi
  [ "$seq" -lt "$count" ] && sleep 0.2
done
[ "$state" != "up" ] && sleep 1
if [ -n "$forever" ]; then
  echo "(LinuxMissions: real ping keeps going until you press Ctrl-C. In scripts, use -c COUNT.)" >&2
fi
echo
echo "--- $host ping statistics ---"
loss=$(( (count - received) * 100 / count ))
echo "$count packets transmitted, $received received, ${loss}% packet loss, time $(( (count - 1) * 200 ))ms"
if [ "$received" -gt 0 ]; then
  echo "$times" | awk '{min=$1; max=$1; s=0; for (i=1;i<=NF;i++){s+=$i; if($i<min)min=$i; if($i>max)max=$i}; printf "rtt min/avg/max/mdev = %.3f/%.3f/%.3f/0.041 ms\n", min, s/NF, max}'
  exit 0
fi
exit 1
MOCK
chmod +x "$SANDBOX/ping"
