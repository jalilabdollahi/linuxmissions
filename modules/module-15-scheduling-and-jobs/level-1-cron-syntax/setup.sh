#!/bin/bash
# Five Schedules: turn five plain-English schedules into crontab lines.
# cron-expand (shared mock) lets the player see when a line would fire.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" --now "2025-01-06 08:00" cron-expand >/dev/null

cat > ticket.txt <<'TICKET'
OPS-2291  Monitoring schedules for the status page
Reported by: Mira Okafor (ops lead)

Please turn these into crontab lines, in this order. The command does not matter
yet: use `true` everywhere, we swap in the real scripts once the schedules are
approved.

  1. Every 15 minutes during business hours, Monday to Friday.
     Business hours are 09:00-17:00; the office is closed from 17:00.
  2. At 02:30 on the 1st of every month (the monthly report).
  3. At 23:00 every Saturday and every Sunday.
  4. At 04:15 every Monday in the first month of each quarter
     (January, April, July and October).
  5. Every two hours, on the hour, day and night (00:00, 02:00, ... 22:00).

Thanks!
TICKET

cat > crontab-fields.txt <<'NOTES'
# How a crontab line is built (from the team wiki)
#
# .---------------- minute        0-59
# |  .------------- hour          0-23
# |  |  .---------- day of month  1-31
# |  |  |  .------- month         1-12 (or jan, feb, ...)
# |  |  |  |  .---- day of week   0-7  (0 and 7 = Sunday, or sun, mon, ...)
# |  |  |  |  |
# *  *  *  *  *   command
NOTES
