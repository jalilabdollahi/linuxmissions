#!/bin/bash
# next-ids.txt = "lena UID GID" and "metrics UID GID" as shadow-utils useradd
# would allocate them from etc/login.defs, etc/passwd and etc/group:
#  - normal accounts: highest used ID inside UID_MIN..UID_MAX, plus 1
#  - system accounts (-r): lowest used ID inside SYS_UID_MIN..SYS_UID_MAX, minus 1
#  - private group: same number as the UID if no group uses it, else allocated
#    the same way inside the GID range.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/login.defs etc/passwd etc/group 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/login.defs, etc/passwd or etc/group was changed; they are the evidence, so type 'reset' to get them back"
  exit 1
fi
if [ ! -f next-ids.txt ]; then
  echo "❌ next-ids.txt does not exist yet"
  exit 1
fi

def() { awk -v k="$1" '$1 == k { v = $2 } END { print v }' etc/login.defs; }
EXP=$(awk -F: \
  -v umin="$(def UID_MIN)" -v umax="$(def UID_MAX)" -v smin="$(def SYS_UID_MIN)" -v smax="$(def SYS_UID_MAX)" \
  -v gmin="$(def GID_MIN)" -v gmax="$(def GID_MAX)" -v sgmin="$(def SYS_GID_MIN)" -v sgmax="$(def SYS_GID_MAX)" '
function newid(used, lo, hi, sys, pref,   k, mn, mx, c) {
  if (pref != "" && pref + 0 >= lo && pref + 0 <= hi && !(pref in used)) return pref
  mn = ""; mx = ""
  for (k in used) { k += 0; if (k >= lo && k <= hi) { if (mn == "" || k < mn) mn = k; if (mx == "" || k > mx) mx = k } }
  if (sys) {
    c = (mn == "") ? hi : mn - 1
    if (c >= lo && !(c in used)) return c
    for (c = hi; c >= lo; c--) if (!(c in used)) return c
  } else {
    c = (mx == "") ? lo : mx + 1
    if (c <= hi && !(c in used)) return c
    for (c = lo; c <= hi; c++) if (!(c in used)) return c
  }
  return -1
}
NR == FNR { if (NF >= 4 && $3 ~ /^[0-9]+$/) uu[$3 + 0] = 1; next }
{ if (NF >= 3 && $3 ~ /^[0-9]+$/) gu[$3 + 0] = 1 }
END {
  lu = newid(uu, umin + 0, umax + 0, 0, "")
  lg = newid(gu, gmin + 0, gmax + 0, 0, lu)
  mu = newid(uu, smin + 0, smax + 0, 1, "")
  mg = newid(gu, sgmin + 0, sgmax + 0, 1, mu)
  print "lena", lu, lg
  print "metrics", mu, mg
}' etc/passwd etc/group)

LU=$(echo "$EXP" | awk '$1 == "lena" { print $2 }');    LG=$(echo "$EXP" | awk '$1 == "lena" { print $3 }')
MU=$(echo "$EXP" | awk '$1 == "metrics" { print $2 }'); MG=$(echo "$EXP" | awk '$1 == "metrics" { print $3 }')

GOT=$(tr -d '\r' < next-ids.txt | grep -v '^[[:space:]]*$')
if [ "$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')" != 2 ] || ! printf '%s\n' "$GOT" | grep -Eq '^[[:space:]]*lena[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]*$' \
   || ! printf '%s\n' "$GOT" | grep -Eq '^[[:space:]]*metrics[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]*$'; then
  echo "❌ next-ids.txt must have exactly two lines: 'lena UID GID' and 'metrics UID GID' (numbers only)"
  exit 1
fi
lu=$(printf '%s\n' "$GOT" | awk '$1 == "lena" { print $2 }');    lg=$(printf '%s\n' "$GOT" | awk '$1 == "lena" { print $3 }')
mu=$(printf '%s\n' "$GOT" | awk '$1 == "metrics" { print $2 }'); mg=$(printf '%s\n' "$GOT" | awk '$1 == "metrics" { print $3 }')

if [ "$lu" != "$LU" ]; then
  if awk -F: -v n="$lu" '$3 == n { f = 1 } END { exit !f }' etc/passwd; then
    echo "❌ lena's UID $lu is already used in etc/passwd"
  else
    echo "❌ lena's UID is not the one useradd would pick (read the regular-user range in login.defs, and look at the highest UID in it)"
  fi
  exit 1
fi
if [ "$lg" != "$LG" ]; then
  if g=$(awk -F: -v n="$lg" '$3 == n { print $1; exit }' etc/group) && [ -n "$g" ]; then
    echo "❌ lena's GID $lg is already taken by the group '$g' in etc/group"
  else
    echo "❌ lena's UID is right, but her private group does not get that GID: useradd takes the UID number only when it is free as a GID, otherwise it allocates a new GID"
  fi
  exit 1
fi
if [ "$mu" != "$MU" ]; then
  if [ "$mu" -ge "$(def UID_MIN)" ] 2>/dev/null; then
    echo "❌ metrics is a system account: its UID comes from the system range, not from the regular-user range"
  elif awk -F: -v n="$mu" '$3 == n { f = 1 } END { exit !f }' etc/passwd; then
    echo "❌ metrics' UID $mu is already used in etc/passwd"
  else
    echo "❌ metrics' UID is wrong: system accounts are allocated downward, from the lowest system UID already in use (see SYS_UID_MIN/SYS_UID_MAX in login.defs)"
  fi
  exit 1
fi
if [ "$mg" != "$MG" ]; then
  if g=$(awk -F: -v n="$mg" '$3 == n { print $1; exit }' etc/group) && [ -n "$g" ]; then
    echo "❌ metrics' GID $mg is already taken by the group '$g' in etc/group"
  else
    echo "❌ metrics' GID is wrong: its UID is already a GID here, so the system group is allocated downward from the lowest system GID in use"
  fi
  exit 1
fi
echo "✅ lena gets UID $LU / GID $LG and metrics UID $MU / GID $MG, as useradd would allocate them"
exit 0
