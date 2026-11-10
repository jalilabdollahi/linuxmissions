#!/bin/bash
# bookings_iso.csv = bookings.csv with column 2 as YYYY-MM-DD (numeric dates
# are day/month/year); everything else byte-identical.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/bookings.sum ] || [ "$(cat bookings.csv README.vendor 2>/dev/null | cksum)" != "$(cat .lm-state/bookings.sum)" ]; then
  echo "❌ bookings.csv or README.vendor was changed or removed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f bookings_iso.csv ]; then
  echo "❌ bookings_iso.csv does not exist yet"
  exit 1
fi

EXPECTED=$(awk -F, -v OFS=, '
  BEGIN { for (i = 1; i <= 12; i++) mon[substr("JanFebMarAprMayJunJulAugSepOctNovDec", 3 * i - 2, 3)] = i }
  NR > 1 {
    if (split($2, p, "/") == 3)      $2 = sprintf("%04d-%02d-%02d", p[3], p[2], p[1])
    else if (split($2, p, " ") == 3) $2 = sprintf("%04d-%02d-%02d", p[3], mon[p[2]], p[1])
  } { print }' bookings.csv)
GOT=$(tr -d '\r' < bookings_iso.csv | sed '/^[[:space:]]*$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ bookings_iso.csv: all $(($(printf '%s\n' "$EXPECTED" | wc -l) - 1)) check-in dates in ISO form, everything else unchanged"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ bookings_iso.csv is empty"; exit 1; fi
if [ "$(printf '%s\n' "$GOT" | head -n 1)" != "booking_id,checkin,nights,room,guest" ]; then
  echo "❌ the first line of bookings_iso.csv must be the unchanged header"
  exit 1
fi
want=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
got=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
if [ "$got" -ne "$want" ]; then
  echo "❌ bookings_iso.csv has $got lines, expected $want (the header and every booking)"
  exit 1
fi
# Walk both files line by line and explain the first difference.
msg=$(paste -d'\n' <(printf '%s\n' "$EXPECTED" | tail -n +2) <(printf '%s\n' "$GOT" | tail -n +2) | paste -d'|' - - |
  awk -F'|' -v src="$(tail -n +2 bookings.csv | cut -d, -f2)" '
  BEGIN { split(src, orig, "\n") }
  $1 != $2 {
    n = split($1, w, ","); split($2, g, ",")
    rest_w = $1; sub(/^[^,]*,[^,]*,/, "", rest_w); rest_g = $2; sub(/^[^,]*,[^,]*,/, "", rest_g)
    if (w[1] != g[1] || rest_w != rest_g) { print "❌ row " NR + 1 " (" w[1] "): only the checkin column may change; the other columns must stay exactly as in bookings.csv (when awk rebuilds a line it joins the fields with OFS)"; exit }
    o = orig[NR]; split(w[2], e, "-")
    if (g[2] == sprintf("%s-%s-%s", e[1], e[3], e[2]))
      print "❌ " o " became " g[2] ", which reads it as month/day; README.vendor says numeric dates are day/month/year"
    else if (g[2] !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/)
      print "❌ " o " became \"" g[2] "\"; write every date as YYYY-MM-DD with two-digit month and day"
    else
      print "❌ " o " became " g[2] ", which is not the same day"
    exit
  }')
if [ -n "$msg" ]; then echo "$msg"; exit 1; fi
echo "❌ bookings_iso.csv differs from the expected result"
exit 1
