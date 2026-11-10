#!/bin/bash
# active = enabled in directory.csv AND a successful login in the log.
# unused_seats.txt = licensed - active; unlicensed_active.txt = active -
# licensed. Usernames lowercase and trimmed, sorted, unique.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs.sum ] || [ "$(cat licenses.txt directory.csv active_30d.log 2>/dev/null | cksum)" != "$(cat .lm-state/inputs.sum)" ]; then
  echo "❌ licenses.txt, directory.csv or active_30d.log was changed or removed; type 'reset' to restore them"
  exit 1
fi
for f in unused_seats.txt unlicensed_active.txt; do
  if [ ! -f "$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
done

export LC_ALL=C
SETS=$(awk '
  FILENAME == "licenses.txt" { u = tolower($0); gsub(/[ \t\r]/, "", u); if (u != "" && u !~ /^#/) lic[u] = 1; next }
  FILENAME == "directory.csv" { split($0, f, ","); if (FNR > 1) { dir[f[1]] = 1; if (f[4] == "yes") on[f[1]] = 1 } next }
  / result=failure / { for (i = 1; i <= NF; i++) if ($i ~ /^user=/) failed[tolower(substr($i, 6))] = 1 }
  / result=success / { for (i = 1; i <= NF; i++) if ($i ~ /^user=/) { u = tolower(substr($i, 6)); seen[u] = 1; if (u in on) act[u] = 1 } }
  END {
    for (u in lic) if (!(u in act)) print "U", u
    for (u in act) if (!(u in lic)) print "A", u
    for (u in seen) if (!(u in on)) print "D", u
    for (u in lic) if ((u in failed) && !(u in seen)) print "F", u
  }' licenses.txt directory.csv active_30d.log)
WANT_U=$(printf '%s\n' "$SETS" | awk '$1 == "U" { print $2 }' | sort)
WANT_A=$(printf '%s\n' "$SETS" | awk '$1 == "A" { print $2 }' | sort)
DISABLED=$(printf '%s\n' "$SETS" | awk '$1 == "D" { print $2 }' | sort)
FAILONLY=$(printf '%s\n' "$SETS" | awk '$1 == "F" { print $2 }' | sort)

check() {   # file wanted label
  local got
  got=$(tr -d '\r' < "$1" | grep -v '^$')
  [ "$got" = "$2" ] && return 0
  if printf '%s\n' "$got" | grep -q '^#\|user=\|,'; then
    echo "❌ $1 must hold only usernames, one per line"
  elif [ "$(printf '%s\n' "$got" | sort -u)" != "$(printf '%s\n' "$got" | sort)" ]; then
    echo "❌ $1 lists some users more than once"
  elif [ "$(printf '%s\n' "$got" | sort)" = "$2" ]; then
    echo "❌ $1 has the right users but is not sorted"
  else
    extra=$(comm -13 <(printf '%s\n' "$2") <(printf '%s\n' "$got" | sort -u) | grep -c .)
    missing=$(comm -23 <(printf '%s\n' "$2") <(printf '%s\n' "$got" | sort -u) | grep -c .)
    echo "❌ $1: $missing user(s) missing and $extra that don't belong ($3)"
  fi
  return 1
}
for f in unused_seats.txt unlicensed_active.txt; do
  if grep -q '[A-Z]' "$f"; then
    echo "❌ $f has capital letters; write every username in lowercase (JDoe and jdoe are the same account)"
    exit 1
  fi
  if tr -d '\r' < "$f" | grep -q '[[:blank:]]'; then
    echo "❌ $f has spaces in it; licenses.txt pads some names with trailing spaces, strip them"
    exit 1
  fi
done
GOT_U=$(tr -d '\r' < unused_seats.txt | tr -d ' ' | grep -v '^$' | sort -u)
MISS_U=$(comm -23 <(printf '%s\n' "$WANT_U") <(printf '%s\n' "$GOT_U"))
if [ -n "$FAILONLY" ] && [ -n "$(comm -12 <(printf '%s\n' "$MISS_U") <(printf '%s\n' "$FAILONLY"))" ]; then
  echo "❌ unused_seats.txt misses licensed users whose only logins failed (result=failure); a failed login does not make anyone active"
  exit 1
fi
if [ -n "$DISABLED" ] && [ -n "$(comm -12 <(printf '%s\n' "$MISS_U") <(printf '%s\n' "$DISABLED"))" ]; then
  echo "❌ unused_seats.txt misses licensed users whose accounts are disabled in directory.csv; they logged in before they left, but their seat is free now"
  exit 1
fi
check unused_seats.txt "$WANT_U" "licensed, but no successful login from an enabled account" || exit 1
if [ -n "$DISABLED" ] && [ -n "$(comm -12 <(printf '%s\n' "$DISABLED") <(tr -d '\r' < unlicensed_active.txt | sort -u))" ]; then
  echo "❌ unlicensed_active.txt lists accounts that are disabled in directory.csv; their logins happened before they were disabled and don't count"
  exit 1
fi
check unlicensed_active.txt "$WANT_A" "successful login from an enabled account, but no seat" || exit 1
echo "✅ $(printf '%s\n' "$WANT_U" | grep -c .) seats can be reclaimed and $(printf '%s\n' "$WANT_A" | grep -c .) active users need one"
