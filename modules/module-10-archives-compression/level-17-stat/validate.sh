#!/bin/bash
# $1 = sandbox path
# Part 1: drift.txt lists exactly the 9 paths setup made drift.
# Part 2: every MANIFEST entry now has its mode and mtime (of the entry itself,
#         not of a symlink's target).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
A=acme-agent

if [ ! -f MANIFEST ] || [ "$(grep -vc '^#' MANIFEST)" -ne 25 ]; then
  echo "❌ MANIFEST is missing or changed; type 'reset'"
  exit 1
fi
if [ ! -L "$A/lib/libacme.so.4" ]; then
  echo "❌ $A/lib/libacme.so.4 is no longer a symlink; type 'reset' to start over"
  exit 1
fi

if [ ! -f drift.txt ]; then
  echo "❌ drift.txt does not exist yet"
  exit 1
fi
expected="$A/bin/acme-ctl
$A/etc/secrets.key
$A/share/doc/Release Notes.txt
$A/var/spool
$A/bin/acme agent helper
$A/lib/libacme.so.4
$A/lib/plugins/http probe.so
$A/VERSION
$A/share/man/acme-agent.8"
want=$(printf '%s\n' "$expected" | LC_ALL=C sort)
got=$(tr -d '\r' < drift.txt | sed -e 's|^\./||' -e 's|/$||' | grep -v '^[[:space:]]*$' | LC_ALL=C sort -u)
if [ "$got" != "$want" ]; then
  wrong=$(printf '%s\n' "$got" | grep -vxF -e "$want" | head -1)
  missing=$(printf '%s\n' "$want" | grep -vxF -e "$got")
  if [ -z "$got" ]; then
    echo "❌ drift.txt is empty (if you already fixed everything, type 'reset': the drift has to be listed first)"
  elif [ -n "$wrong" ]; then
    if grep -qF " $wrong" MANIFEST; then
      echo "❌ drift.txt lists '$wrong', but its mode and mtime matched MANIFEST"
    else
      echo "❌ drift.txt lists '$wrong', which is not a MANIFEST path (write paths exactly as MANIFEST does)"
    fi
  elif [ "$missing" = "$A/lib/libacme.so.4" ]; then
    echo "❌ drift.txt misses 1 path: look at a symlink's own mtime, not its target's"
  else
    echo "❌ drift.txt misses $(printf '%s\n' "$missing" | grep -c .) drifted path(s)"
  fi
  exit 1
fi

grep -v '^#' MANIFEST | while read -r mode epoch path; do
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    echo "❌ $path is missing; type 'reset'"
    exit 1
  fi
  now=$(stat -c '%a %Y' "$path")
  if [ "$now" != "$mode $epoch" ]; then
    if [ "${now% *}" != "$mode" ]; then
      echo "❌ drift.txt is right; now fix the bundle: $path has mode ${now% *}, MANIFEST says $mode"
    else
      echo "❌ drift.txt is right; now fix the bundle: $path has mtime ${now#* }, MANIFEST says $epoch"
    fi
    exit 1
  fi
done || exit 1

echo "✅ drift.txt lists the 9 drifted paths and the bundle now matches MANIFEST exactly"
exit 0
