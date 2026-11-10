#!/bin/bash
# Bookings with the check-in date in three styles. Most numeric dates have a
# day of 12 or less, so reading them as US month/day gives a valid but wrong
# date without any error. Guest names come last and some are quoted with a
# comma inside.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

cat > README.vendor <<'TXT'
Front-desk export, bookings module
==================================
checkin   Arrival date, typed by staff. Three styles are in use:
          day/month/year (European order, e.g. 03/11/2026 or 3/11/2026),
          ISO year-month-day (2026-11-03) and day month-name year (3 Nov 2026).
nights    Number of nights.
room      Room type code.
guest     Lead guest, "Last, First" when typed by the night shift.
TXT

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", mon, " ")
  split("31 28 31 30 31 30 31 31 30 31 30 31", mdays, " ")
  nr = split("DBL TWN SGL SUITE FAM", room, " ")
  ng = split("Maria Lopez|Kofi Mensah|\"Okafor, Chinedu\"|Annika Berg|Luca Romano|\"Nguyen, Thi Lan\"|Pierre Martin|Sara Cohen|\"Kowalska, Ewa\"|Tom Bradley|Ayumi Sato|Omar Haddad", guest, "|")
  print "booking_id,checkin,nights,room,guest"
  n = 160 + int(rand() * 80)
  id = 240000 + int(rand() * 50000)
  for (i = 1; i <= n; i++) {
    y = (rand() < 0.7) ? 2026 : 2027
    m = 1 + int(rand() * 12)
    d = (rand() < 0.7) ? 1 + int(rand() * 12) : 1 + int(rand() * mdays[m])
    r = rand()
    if (r < 0.30)      date = sprintf("%02d/%02d/%d", d, m, y)
    else if (r < 0.50) date = sprintf("%d/%d/%d", d, m, y)
    else if (r < 0.75) date = sprintf("%d-%02d-%02d", y, m, d)
    else               date = sprintf("%d %s %d", d, mon[m], y)
    printf "B%d,%s,%d,%s,%s\n", id, date, 1 + int(rand() * 9), room[int(rand() * nr) + 1], guest[int(rand() * ng) + 1]
    id += 1 + int(rand() * 7)
  }
}' > bookings.csv

cat bookings.csv README.vendor | cksum > .lm-state/bookings.sum
