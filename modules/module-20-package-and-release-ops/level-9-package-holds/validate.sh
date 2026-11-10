#!/bin/bash
# Holds (as dpkg records them) must be exactly the two frozen packages; nothing
# may have been upgraded for real; upgrade-plan.txt must be the simulated plan
# that respects the holds (same Inst set as a fresh simulation).
SANDBOX="$1"
ROOT="$SANDBOX/rootfs"
export APT_CONFIG="$ROOT/etc/apt/apt.conf"
HOLD="$(/usr/bin/dpkg --root="$ROOT" --get-selections 2>/dev/null | awk '$2 == "hold" {print $1}' | sort)"
WANT=$'linux-image-generic\npostgresql-16'

if [ "$(/usr/bin/dpkg-query --root="$ROOT" -W -f='${Package} ${Version}\n' | sort)" != "$(sort "$SANDBOX/.lm/baseline")" ]; then
  echo "❌ some package was really upgraded or removed; only plan the upgrade (type reset to start over)"
  exit 1
fi
for n in $WANT; do
  if ! echo "$HOLD" | grep -qx "$n"; then
    echo "❌ $n is not on hold yet"
    exit 1
  fi
done
EXTRA="$(comm -13 <(echo "$WANT") <(echo "$HOLD") | head -1)"
if [ -n "$EXTRA" ]; then
  echo "❌ $EXTRA is on hold as well, but the freeze only covers the two packages in FREEZE.txt"
  exit 1
fi
if [ ! -f "$SANDBOX/upgrade-plan.txt" ]; then
  echo "❌ the holds are right; now save the simulated upgrade plan to upgrade-plan.txt"
  exit 1
fi
PLAN="$(grep '^Inst ' "$SANDBOX/upgrade-plan.txt" | awk '{print $2}' | sort)"
REAL="$(/usr/bin/apt-get -s upgrade 2>/dev/null | grep '^Inst ' | awk '{print $2}' | sort)"
if [ -z "$PLAN" ]; then
  echo "❌ upgrade-plan.txt has no 'Inst' lines: it should be the output of a simulated upgrade"
  exit 1
fi
HELD_IN_PLAN="$(echo "$PLAN" | grep -x -e postgresql-16 -e linux-image-generic | head -1)"
if [ -n "$HELD_IN_PLAN" ]; then
  echo "❌ upgrade-plan.txt would upgrade $HELD_IN_PLAN: it was saved before the hold took effect"
  exit 1
fi
if [ "$PLAN" != "$REAL" ]; then
  echo "❌ upgrade-plan.txt does not match what a simulated upgrade plans now ($(echo "$PLAN" | wc -l) upgrades there, $(echo "$REAL" | wc -l) expected)"
  exit 1
fi
echo "✅ the two frozen packages are on hold and the other $(echo "$REAL" | wc -l) upgrades are still planned"
