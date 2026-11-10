#!/bin/bash
# The Percent Sign: the hourly report line uses $(date +%F-%H) without
# escaping %, so cron cuts the command at the first % and the shell sees an
# unfinished $( ... ). cron-run (shared mock) produced the error mails.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" --user deploy --now "2025-06-10 08:40" cron-run >/dev/null
mkdir -p app reports archive notes var/mail

cat > app/report.sh <<'SH'
#!/bin/sh
# Hourly sales summary (fixture data instead of the real database query).
echo "Hourly sales report $(date '+%Y-%m-%d %H:00')"
echo "orders   37"
echo "revenue  1912.40 EUR"
echo "refunds  2"
SH
cat > app/notify.sh <<'SH'
#!/bin/sh
# Appends the message it reads on stdin to the team notes.
cat >> "$(dirname "$0")/../notes/reminders.txt"
SH
chmod 755 app/report.sh app/notify.sh

for h in 06 07 08 09 10 11 12 13 14 15 16 17; do
  echo "Hourly sales report 2025-06-08 $h:00" > "reports/report-2025-06-08-$h.txt"
done

cat > crontab.txt <<CRON
# deploy's crontab, master copy (install with: crontab crontab.txt)
MAILTO=deploy

# hourly sales report, one file per hour
0 * * * * $SANDBOX/app/report.sh > $SANDBOX/reports/report-\$(date +%F-%H).txt

# 00:20 pack the reports of the day before
20 0 * * * tar -czf $SANDBOX/archive/reports-\$(date -d yesterday +\\%F).tgz -C $SANDBOX/reports .

# Monday 08:00 reminder; the text after % is the message on stdin
0 8 * * 1 $SANDBOX/app/notify.sh%Weekly check: are last week's reports complete?
CRON

# The mails cron sent since the change (yesterday 13:00 to 17:00).
mkdir -p "$SANDBOX/.cron-sim"
"$SANDBOX/bin/cron-run" --root "$SANDBOX/.cron-sim" --home "$SANDBOX" --crontab "$SANDBOX/crontab.txt:deploy" \
  --from "2025-06-09 13:00" --to "2025-06-09 17:00" --no-periodic --mail-dir "$SANDBOX/var/mail" -q >/dev/null 2>&1
rm -rf "$SANDBOX/.cron-sim"
