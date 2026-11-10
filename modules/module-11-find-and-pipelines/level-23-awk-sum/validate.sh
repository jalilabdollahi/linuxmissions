#!/bin/bash
# usage.txt = user<TAB>GiB<TAB>stale_GiB per user (2 decimals, GiB = 2^30
# bytes, stale = last modified before 2025-01-01), largest GiB first.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/files.sum ] || [ "$(cksum < files.lst 2>/dev/null)" != "$(cat .lm-state/files.sum)" ]; then
  echo "❌ files.lst was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f usage.txt ]; then
  echo "❌ usage.txt does not exist yet"
  exit 1
fi

EXPECTED=$(awk -F'\t' 'NF == 4 { t[$2] += $3; if ($4 < "2025-01-01") s[$2] += $3 }
  END { for (u in t) printf "%s\t%.2f\t%.2f\n", u, t[u] / 1073741824, s[u] / 1073741824 }' files.lst | sort -t"$(printf '\t')" -k2,2nr)
GOT=$(tr -d '\r' < usage.txt | sed '/^[[:space:]]*$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ usage.txt: GiB and stale GiB for all $(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ') users, biggest first"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ usage.txt is empty"; exit 1; fi
if printf '%s\n' "$GOT" | grep -q '^find\|Permission\|^[[:space:]]'; then
  echo "❌ usage.txt has a line for the 'find: ... Permission denied' errors (or an empty user name): those lines are not files, skip them"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -q '/'; then
  echo "❌ usage.txt has paths in the user column: the paths contain spaces, so split the fields on tabs only"
  exit 1
fi
if printf '%s\n' "$GOT" | awk -F'\t' 'NF != 3 { f = 1 } END { exit !f }'; then
  echo "❌ every line of usage.txt must be user, GiB and stale GiB separated by tabs"
  exit 1
fi
if printf '%s\n' "$GOT" | awk -F'\t' '$2 !~ /^[0-9]+\.[0-9][0-9]$/ || $3 !~ /^[0-9]+\.[0-9][0-9]$/ { f = 1 } END { exit !f }'; then
  echo "❌ write both amounts with exactly two decimals, e.g. 123.45"
  exit 1
fi
want_users=$(printf '%s\n' "$EXPECTED" | cut -f1 | sort)
got_users=$(printf '%s\n' "$GOT" | cut -f1 | sort)
if [ "$want_users" != "$got_users" ]; then
  echo "❌ usage.txt should have exactly one line per user ($(printf '%s\n' "$want_users" | wc -l | tr -d ' ') users), it has: $(printf '%s\n' "$got_users" | tr '\n' ' ')"
  exit 1
fi
# per-user comparison
msg=$(printf '%s\n' "$GOT" | awk -F'\t' -v want="$EXPECTED" '
  BEGIN { n = split(want, r, "\n"); for (i = 1; i <= n; i++) { split(r[i], f, "\t"); g[f[1]] = f[2]; s[f[1]] = f[3] } }
  $2 != g[$1] {
    if (g[$1] > 0 && ($2 / g[$1] > 1.07 && $2 / g[$1] < 1.08)) print "❌ " $1 " has " $2 " in usage.txt but " g[$1] " GiB: a GiB is 1024^3 = 1073741824 bytes, not 10^9"
    else print "❌ the GiB total for " $1 " is not right (" $2 ")"
    exit }
  $3 != s[$1] { print "❌ the stale total for " $1 " is not right (" $3 "): stale means last modified before 2025-01-01"; exit }')
if [ -n "$msg" ]; then
  echo "$msg"
  exit 1
fi
echo "❌ the numbers are right, but the lines must be sorted by GiB, largest first"
exit 1
