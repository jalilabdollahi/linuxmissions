#!/bin/bash
# Hanging Healthchecks: healthcheck.sh answers fast for most hosts, fails
# fast for some, and hangs forever for others (one of them even ignores
# SIGTERM). Which host does what is shuffled on every setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm

cat > hosts.txt <<'EOF'
web-01.prod
web-02.prod
web-03.prod
api-01.prod
api-02.prod
queue-01.prod
cache-01.prod
cache-02.prod
db-01.prod
db-02.prod
search-01.prod
mail-01.prod
EOF

# Behaviours: 5 answer (one of them slowly, 2+ s), 3 fail fast, 4 hang
# (one of those ignores SIGTERM).
paste -d' ' hosts.txt <(printf '%s\n' ok ok ok ok slow refused refused http503 hang hang hang stubborn | shuf) > .lm/fleet

cat > healthcheck.sh <<'EOF'
#!/bin/bash
# healthcheck.sh HOST - GET http://HOST:8080/healthz
# exit 0: healthy   exit 1/2: unhealthy   (and sometimes it never returns...)
host="$1"
if [ -z "$host" ]; then echo "usage: healthcheck.sh HOST" >&2; exit 2; fi
here="$(cd "$(dirname "$0")" && pwd)"
runs="$here/.lm/runs"
mode=$(awk -v h="$host" '$1 == h { print $2 }' "$here/.lm/fleet")
now() { date +%s.%N; }
echo "start $host $$ $(now)" >> "$runs"
case "$mode" in
  ok)
    sleep "0.$((RANDOM % 5 + 2))"
    echo "$host: HTTP 200 OK"
    echo "end $host $$ $(now) 0" >> "$runs"; exit 0 ;;
  slow)
    sleep "2.$((RANDOM % 4))"
    echo "$host: HTTP 200 OK (slow)"
    echo "end $host $$ $(now) 0" >> "$runs"; exit 0 ;;
  refused)
    sleep 0.1
    echo "$host: connect to port 8080: Connection refused" >&2
    echo "end $host $$ $(now) 1" >> "$runs"; exit 1 ;;
  http503)
    sleep 0.3
    echo "$host: HTTP 503 Service Unavailable" >&2
    echo "end $host $$ $(now) 2" >> "$runs"; exit 2 ;;
  hang)
    trap 'echo "term $host $$ $(now)" >> "$runs"; exit 143' TERM
    ;;
  stubborn)
    trap 'echo "term $host $$ $(now)" >> "$runs"' TERM
    ;;
  *)
    echo "$host: Name or service not known" >&2
    echo "end $host $$ $(now) 2" >> "$runs"; exit 2 ;;
esac
# The connection was accepted but nothing ever answers.
while [ "$SECONDS" -lt 120 ]; do sleep 0.2; done
exit 1
EOF
chmod +x healthcheck.sh

cat > NOTE.txt <<'EOF'
The nightly fleet report has not finished for three nights: it calls
./healthcheck.sh for each host in hosts.txt, and for some hosts the check
never returns. Ops wants report.txt in the morning, one line per host in
the order of hosts.txt:

  web-01.prod OK
  web-02.prod FAIL
  ...

OK = the check passed, FAIL = it failed, TIMEOUT = no answer within 3 seconds.
EOF
