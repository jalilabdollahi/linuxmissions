#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/table.txt"

if [ ! -f "$FILE" ]; then
  echo "❌ table.txt not found"
  exit 1
fi
if grep -q "$(printf '\t')" "$FILE"; then
  echo "❌ table.txt contains tabs; align the columns with spaces so it looks the same everywhere"
  exit 1
fi

# The data the table must show, row by row, field by field.
CSV='service,owner,status,port,description
api,payments,healthy,8080,Public REST API
worker,payments,degraded,9090,Background job runner
cache,platform,healthy,6379,Redis session cache
auth,identity,healthy,8443,Login and token service
search,discovery,healthy,9200,Product search index
mailer,growth,down,2525,Transactional e-mail sender
billing,payments,healthy,8081,Invoices and refunds
gateway,platform,healthy,443,Edge proxy and TLS termination
reports,finance,degraded,8090,Nightly PDF reports
metrics,platform,healthy,9100,Prometheus exporter
scheduler,platform,healthy,8070,Cron replacement for jobs
geoip,discovery,healthy,8085,IP to country lookup
ledger,finance,healthy,5433,Double-entry bookkeeping DB
chat-bot,support,down,3000,Customer support assistant'

TABLE="$(tr -d '\r' < "$FILE" | sed '/^[[:space:]]*$/d')"
rows="$(printf '%s\n' "$TABLE" | wc -l | tr -d ' ')"
if [ "$rows" -ne 15 ]; then
  echo "❌ table.txt has $rows non-empty lines; expected the header plus 14 services"
  exit 1
fi

# For each table line, find each CSV field in order; text between fields must be
# spaces only. Record each field's start column and require it to be the same in
# every line (left-aligned columns).
RESULT="$(printf '%s\n' "$CSV" | awk -F, -v tf="$FILE" '
  BEGIN { while ((getline l < tf) > 0) { sub(/\r$/, "", l); if (l ~ /[^[:space:]]/) line[++n] = l } }
  {
    r = NR; s = line[r]; pos = 1
    for (k = 1; k <= NF; k++) {
      rest = substr(s, pos); i = index(rest, $k)
      if (i == 0) { print "MISSING|" r "|" $k; done = 1; exit }
      gap = substr(rest, 1, i - 1)
      if (gap ~ /[^ ]/) { print "JUNK|" r "|" gap; done = 1; exit }
      if (k > 1 && length(gap) < 1) { print "NOGAP|" r; done = 1; exit }
      start = pos + i - 1
      if (r == 1) col[k] = start
      else if (col[k] != start) { print "ALIGN|" r "|" k; done = 1; exit }
      pos = start + length($k)
    }
    if (substr(s, pos) ~ /[^ ]/) { print "EXTRA|" r; done = 1; exit }
  }
  END { if (!done) print "OK" }')"

case "$RESULT" in
  MISSING*) echo "❌ line $(echo "$RESULT" | cut -d'|' -f2) of table.txt does not contain the value '$(echo "$RESULT" | cut -d'|' -f3)' as one piece (was a column split on its spaces?)" ;;
  JUNK*)    echo "❌ line $(echo "$RESULT" | cut -d'|' -f2) has characters other than spaces between columns ('$(echo "$RESULT" | cut -d'|' -f3)')" ;;
  NOGAP*)   echo "❌ line $(echo "$RESULT" | cut -d'|' -f2) has columns touching each other; leave at least one space" ;;
  ALIGN*)   echo "❌ column $(echo "$RESULT" | cut -d'|' -f3) does not start at the same position on line $(echo "$RESULT" | cut -d'|' -f2) as on the header line" ;;
  EXTRA*)   echo "❌ line $(echo "$RESULT" | cut -d'|' -f2) has extra text after the last column" ;;
  OK)       echo "✅ table.txt shows every service in left-aligned columns"; exit 0 ;;
  *)        echo "❌ table.txt could not be checked" ;;
esac
exit 1
