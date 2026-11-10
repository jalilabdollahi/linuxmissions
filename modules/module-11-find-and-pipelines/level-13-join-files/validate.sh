#!/bin/bash
# owners.txt = one "ip mac owner" line per lease, MAC as in the lease file,
# UNKNOWN when the inventory has no such MAC, sorted by IP numerically.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs.sum ] || [ "$(cat dnsmasq.leases inventory.csv 2>/dev/null | cksum)" != "$(cat .lm-state/inputs.sum)" ]; then
  echo "❌ dnsmasq.leases or inventory.csv was changed or removed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f owners.txt ]; then
  echo "❌ owners.txt does not exist yet"
  exit 1
fi

# The expected answer, built with awk instead of join: normalise the
# inventory MACs, look up every lease.
EXPECTED=$(awk -F, '
  NR == FNR { if (FNR > 1) { m = tolower($1); gsub(/-/, ":", m); own[m] = $2 } next }
  { split($0, f, " "); print f[3], f[2], ((f[2] in own) ? own[f[2]] : "UNKNOWN") }' inventory.csv dnsmasq.leases \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n)
GOT=$(tr -d '\r' < owners.txt | awk 'NF { $1 = $1; print }')
want=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
got=$(printf '%s\n' "$GOT" | grep -c .)

if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ owners.txt names the owner of all $want leased devices, sorted by IP"
  exit 0
fi

if [ "$got" -eq 0 ]; then
  echo "❌ owners.txt is empty"
  exit 1
fi
bad=$(printf '%s\n' "$GOT" | awk 'NF != 3 { print NR; exit }')
if [ -n "$bad" ]; then
  echo "❌ line $bad of owners.txt is not 'ip mac owner' (three fields)"
  exit 1
fi
if printf '%s\n' "$GOT" | awk '$1 !~ /^10\.20\.[01]\.[0-9]+$/ { f = 1 } END { exit !f }'; then
  echo "❌ the first field of every line must be the lease IP (order: ip mac owner)"
  exit 1
fi
if printf '%s\n' "$GOT" | awk '$2 ~ /[A-F-]/ { f = 1 } END { exit !f }'; then
  echo "❌ write the MACs as the lease file does (lowercase, with colons), not in the inventory's format"
  exit 1
fi
if [ "$got" -lt "$want" ]; then
  if ! printf '%s\n' "$GOT" | grep -q ' UNKNOWN$'; then
    echo "❌ owners.txt has $got lines but there are $want leases: leases without an inventory entry must appear too, marked UNKNOWN"
  else
    echo "❌ owners.txt has $got lines but there are $want leases: join silently skips lines when an input is not sorted on the join field"
  fi
  exit 1
fi
if [ "$got" -gt "$want" ]; then
  echo "❌ owners.txt has $got lines but there are only $want leases"
  exit 1
fi
unknown_want=$(printf '%s\n' "$EXPECTED" | grep -c ' UNKNOWN$')
unknown_got=$(printf '%s\n' "$GOT" | grep -c ' UNKNOWN$')
if [ "$unknown_got" -gt "$unknown_want" ]; then
  echo "❌ $unknown_got devices are UNKNOWN, but only $unknown_want are missing from the inventory: the MACs must match exactly after normalising (case, - vs :), and join only finds partners when both inputs are sorted on the MAC"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | sort)" != "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  wrong=$(comm -13 <(printf '%s\n' "$EXPECTED" | sort) <(printf '%s\n' "$GOT" | sort) | grep -c .)
  echo "❌ $wrong line(s) pair an IP, MAC and owner that don't belong together"
  exit 1
fi
echo "❌ the lines are right but not sorted by IP numerically (10.20.0.9 comes before 10.20.0.10, and 10.20.0.x before 10.20.1.x)"
exit 1
