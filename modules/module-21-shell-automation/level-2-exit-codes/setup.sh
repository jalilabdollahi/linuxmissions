#!/bin/bash
# check_queue.sh prints the right words but always exits 0: its last command
# is an echo, and the missing-file case falls through to "OK".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p spool

cat > check_queue.sh <<'EOF'
#!/bin/bash
# check_queue.sh STATS_FILE - Nagios check for the mail queue.
# STATS_FILE is the snapshot the mail server writes every minute
# (key=value lines; we look at deferred=).
#
# Monitoring reads ONE line of output and the EXIT STATUS:
#   OK - 42 deferred                    exit 0   fewer than 100 deferred
#   WARNING - 150 deferred              exit 1   100 to 499
#   CRITICAL - 900 deferred             exit 2   500 or more
#   UNKNOWN - no queue data in FILE     exit 3   file missing or unreadable, or
#                                                no numeric deferred= line
#                                                (FILE = the argument as given)

file=$1
deferred=$(sed -n 's/^deferred=//p' "$file")

if [ "$deferred" -ge 500 ]; then
  echo "CRITICAL - $deferred deferred"
elif [ "$deferred" -ge 100 ]; then
  echo "WARNING - $deferred deferred"
else
  echo "OK - $deferred deferred"
fi

echo "check done"
EOF
chmod +x check_queue.sh

printf '%s\n' '# mailq snapshot 2026-11-10T03:00:01' 'active=4' 'deferred=37' 'hold=0' > spool/mx1.stats
printf '%s\n' '# mailq snapshot 2026-11-10T03:00:01' 'active=11' 'deferred=268' 'hold=2' > spool/mx2.stats
printf '%s\n' '# mailq snapshot 2026-11-10T03:00:02' 'active=40' 'deferred=1874' 'hold=0' > spool/mx3.stats
# mx4 died last night: its snapshot was never written.

cat > monitoring.log <<'EOF'
2026-11-10 03:00:05 check_queue mx1  status=0  "OK - 37 deferred"
2026-11-10 03:00:05 check_queue mx2  status=0  "WARNING - 268 deferred"
2026-11-10 03:00:05 check_queue mx3  status=0  "CRITICAL - 1874 deferred"
2026-11-10 03:00:05 check_queue mx4  status=0  "OK -  deferred"
2026-11-10 03:00:05 dashboard: all 4 mail queues GREEN (status 0)
EOF
