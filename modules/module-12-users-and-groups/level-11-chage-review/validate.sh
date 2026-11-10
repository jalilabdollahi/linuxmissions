#!/bin/bash
# expiring.txt = "user YYYY-MM-DD" (password expiry date), sorted by date, for every
# account whose password expires on or before 2026-11-24 (ticket date 2026-11-10
# plus 14 days), including the ones already expired. Password expiry = last change
# (shadow field 3) + max days (field 5); max 99999 or empty = never; last change 0
# = must change at next login, listed with the ticket date. Account expiry (field 8)
# is a different thing.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/shadow etc/passwd .lm/now 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/shadow or etc/passwd was changed; they are the evidence, so type 'reset' to get them back"
  exit 1
fi
if [ ! -f expiring.txt ]; then
  echo "❌ expiring.txt does not exist yet"
  exit 1
fi

TODAY=$(( $(date -u -d 2026-11-10 +%s) / 86400 ))
LIMIT=$((TODAY + 14))
day2date() { date -u -d "1970-01-01 +$1 days" +%F; }

WANT=$(awk -F: -v t="$TODAY" -v lim="$LIMIT" '
  $3 == "" || $5 == "" || $5 + 0 >= 99999 { next }
  { e = ($3 == "0") ? t : $3 + $5 }
  e <= lim { print $1, e }' etc/shadow | while read -r u d; do echo "$u $(day2date "$d")"; done | LC_ALL=C sort)

GOT=$(tr -d '\r' < expiring.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]][[:space:]]*/ /g' | grep -v '^$')
if [ -z "$GOT" ]; then
  echo "❌ expiring.txt is empty"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -Evq '^[a-z_][a-z0-9_-]* [0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "❌ every line of expiring.txt must be 'user YYYY-MM-DD', e.g. 'amara 2026-11-17'; this line is not: $(printf '%s\n' "$GOT" | grep -Ev '^[a-z_][a-z0-9_-]* [0-9]{4}-[0-9]{2}-[0-9]{2}$' | head -n 1)"
  exit 1
fi

why() { awk -F: -v u="$1" '$1 == u { print "last=" $3 " max=" $5 " acct=" $8 }' etc/shadow; }
GU=$(printf '%s\n' "$GOT" | awk '{ print $1 }' | LC_ALL=C sort)
WU=$(printf '%s\n' "$WANT" | awk '{ print $1 }')
while IFS= read -r u; do
  [ -z "$u" ] && continue
  printf '%s\n' "$WU" | grep -qxF -- "$u" && continue
  read -r last max acct <<< "$(awk -F: -v u="$u" '$1 == u { print ($3 == "" ? "-" : $3), ($5 == "" ? "-" : $5), ($8 == "" ? "-" : $8) }' etc/shadow)"
  if [ -z "$last" ]; then
    echo "❌ '$u' is not an account in etc/shadow"
  elif [ "$max" = 99999 ]; then
    if [ "$acct" != "-" ]; then
      echo "❌ $u: that is the ACCOUNT expiry (field 8); the password itself never expires (maximum age 99999)"
    else
      echo "❌ $u: a maximum age of 99999 days means the password never expires"
    fi
  elif [ "$max" = "-" ] || [ "$last" = "-" ]; then
    echo "❌ $u has no password aging (an empty last-change or maximum field), so no expiry date exists"
  else
    echo "❌ $u's password expires on $(day2date $((last + max))), after the 14-day window"
  fi
  exit 1
done <<< "$GU"
while IFS= read -r u; do
  printf '%s\n' "$GU" | grep -qxF -- "$u" && continue
  last=$(awk -F: -v u="$u" '$1 == u { print $3 }' etc/shadow)
  if [ "$last" = 0 ]; then
    echo "❌ an account whose last change is 0 is missing: it must change its password at next login, which counts as expired now"
  else
    echo "❌ an account whose password expires within 14 days, or already has, is missing from expiring.txt"
  fi
  exit 1
done <<< "$WU"
if [ "$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')" != "$(printf '%s\n' "$GU" | wc -l | tr -d ' ')" ]; then
  echo "❌ an account appears twice in expiring.txt"
  exit 1
fi
while read -r u d; do
  g=$(printf '%s\n' "$GOT" | awk -v u="$u" '$1 == u { print $2 }')
  if [ "$g" != "$d" ]; then
    echo "❌ $u is right to be on the list, but the date $g is wrong (password expiry = days since 1970-01-01 of the last change + maximum age; last change 0 means expired now)"
    exit 1
  fi
done <<< "$WANT"
PREV=""
while read -r u d; do
  if [ -n "$PREV" ] && [[ "$d" < "$PREV" ]]; then
    echo "❌ expiring.txt is not sorted by date: $u ($d) comes after $PREV"
    exit 1
  fi
  PREV=$d
done <<< "$GOT"
echo "✅ expiring.txt lists the $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') accounts whose passwords expire by 2026-11-24, in date order"
exit 0
