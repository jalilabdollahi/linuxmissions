#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/hosts.txt" <<'EOF'
app.internal
www.internal
api.internal
db.internal
legacy.internal
cache.internal
EOF

# The internal zone served by the (simulated) resolver 10.20.4.2.
mkdir -p "$SANDBOX/.dns"
cat > "$SANDBOX/.dns/zone" <<'EOF'
app.internal.      300  A      10.10.0.5
www.internal.      300  CNAME  app-lb.internal.
app-lb.internal.   60   A      10.10.0.30
api.internal.      60   A      10.10.0.41
api.internal.      60   A      10.10.0.42
db.internal.       300  A      10.10.0.8
cache.internal.    300  CNAME  redis-1.internal.
redis-1.internal.  300  A      10.10.0.9
mail.internal.     3600 MX     10 mx1.internal.
mx1.internal.      3600 A      10.10.0.25
EOF
: > "$SANDBOX/.dns/query.log"

# ./dig - stand-in for dig(1) from BIND 9.18. The sandbox has no network and
# no DNS server, so it answers from .dns/zone using dig's output format.
# Supports: dig [@server] [-t TYPE] [TYPE] NAME [+short] [+noall +answer]
cat > "$SANDBOX/dig" <<'MOCK'
#!/bin/bash
here="$(cd "$(dirname "$0")" && pwd)"
zone="$here/.dns/zone"
server="10.20.4.2" type="A" name="" short="" answer_only=""
while [ $# -gt 0 ]; do
  case "$1" in
    @*) server="${1#@}" ;;
    -t) type="$(echo "$2" | tr a-z A-Z)"; shift ;;
    +short) short=1 ;;
    +noall) answer_only=1 ;;
    +answer|+nocmd|+nostats|+nocomments|+noquestion) ;;
    +*) ;;
    -h|--help) echo "Usage: dig [@server] [-t type] [type] name [+short] [+noall +answer]  (LinuxMissions stand-in)"; exit 0 ;;
    -*) echo "Invalid option: $1" >&2; exit 1 ;;
    A|a|AAAA|aaaa|MX|mx|CNAME|cname|NS|ns|TXT|txt|ANY|any) type="$(echo "$1" | tr a-z A-Z)" ;;
    *) name="$1" ;;
  esac
  shift
done
if [ -z "$name" ]; then
  echo "(LinuxMissions: this dig only knows the internal zone; give it a name, e.g. ./dig app.internal)" >&2
  exit 1
fi
echo "$name" >> "$here/.dns/query.log"
fq="${name%.}."

# Collect answer records: follow CNAMEs (max 5) like a recursive resolver.
answers=""
cur="$fq"
for _ in 1 2 3 4 5; do
  recs="$(awk -v n="$cur" -v t="$type" 'tolower($1) == tolower(n) && ($3 == t || $3 == "CNAME" || t == "ANY")' "$zone")"
  [ -z "$recs" ] && break
  answers="$answers$recs"$'\n'
  cname="$(printf '%s\n' "$recs" | awk '$3 == "CNAME" {print $4; exit}')"
  [ -z "$cname" ] || [ "$type" = "CNAME" ] && break
  cur="$cname"
done
answers="$(printf '%s' "$answers" | sed '/^$/d')"
exists="$(awk -v n="$fq" 'tolower($1) == tolower(n)' "$zone")"
if [ -n "$exists" ]; then status="NOERROR"; else status="NXDOMAIN"; fi
count="$(printf '%s\n' "$answers" | sed '/^$/d' | wc -l | tr -d ' ')"

fmt() { awk '{ rest = $4; for (i = 5; i <= NF; i++) rest = rest " " $i; printf "%-24s%s\tIN\t%s\t%s\n", $1, $2, $3, rest }'; }

if [ -n "$short" ]; then
  printf '%s\n' "$answers" | sed '/^$/d' | awk '{ rest = $4; for (i = 5; i <= NF; i++) rest = rest " " $i; print rest }'
  exit 0
fi
if [ -n "$answer_only" ]; then
  [ -n "$answers" ] && printf '%s\n' "$answers" | fmt
  exit 0
fi

# Like real dig, stop quietly if the reader goes away (e.g. `| head`).
exec 2>/dev/null
id=$(( (RANDOM % 60000) + 1000 ))
auth=0; [ "$count" = "0" ] && auth=1
echo
echo "; <<>> DiG 9.18.28-0ubuntu0.24.04.1-Ubuntu <<>> $name"
echo ";; global options: +cmd"
echo ";; Got answer:"
echo ";; ->>HEADER<<- opcode: QUERY, status: $status, id: $id"
echo ";; flags: qr rd ra; QUERY: 1, ANSWER: $count, AUTHORITY: $auth, ADDITIONAL: 1"
echo
echo ";; OPT PSEUDOSECTION:"
echo "; EDNS: version: 0, flags:; udp: 1232"
echo ";; QUESTION SECTION:"
printf ';%-23s\tIN\t%s\n' "$fq" "$type"
echo
if [ "$count" != "0" ]; then
  echo ";; ANSWER SECTION:"
  printf '%s\n' "$answers" | fmt
else
  echo ";; AUTHORITY SECTION:"
  printf '%-24s%s\tIN\t%s\t%s\n' "internal." "300" "SOA" "ns1.internal. hostmaster.internal. 2026111001 3600 900 604800 300"
fi
echo
echo ";; Query time: $(( (RANDOM % 4) + 1 )) msec"
echo ";; SERVER: $server#53($server) (UDP)"
echo ";; WHEN: $(date '+%a %b %d %H:%M:%S %Z %Y')"
echo ";; MSG SIZE  rcvd: $(( 40 + count * 24 ))"
echo
exit 0
MOCK
chmod +x "$SANDBOX/dig"
