#!/bin/bash
# Exit with the status on each branch, catch the missing/empty/non-numeric
# cases first, and drop the trailing echo.
cat > check_queue.sh <<'SCRIPT'
#!/bin/bash
# check_queue.sh STATS_FILE - Nagios check for the mail queue.
file=$1
deferred=$(sed -n 's/^deferred=//p' "$file" 2>/dev/null)

case $deferred in
  ''|*[!0-9]*)
    echo "UNKNOWN - no queue data in $file"
    exit 3 ;;
esac

if [ "$deferred" -ge 500 ]; then
  echo "CRITICAL - $deferred deferred"
  exit 2
elif [ "$deferred" -ge 100 ]; then
  echo "WARNING - $deferred deferred"
  exit 1
fi
echo "OK - $deferred deferred"
exit 0
SCRIPT
for f in spool/mx1.stats spool/mx2.stats spool/mx3.stats spool/mx4.stats; do
  ./check_queue.sh "$f"; echo "exit $?"
done
