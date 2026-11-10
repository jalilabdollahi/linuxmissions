#!/bin/bash
# failed_units.txt must equal the units with a [FAILED] line, in first-failure order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cksum sysroot/var/log/boot.log 2>/dev/null | cmp -s - .lm-state/sum; then
  echo "❌ boot.log was changed; it is the evidence, so type 'reset' to get it back"
  exit 1
fi
[ -s failed_units.txt ] || { echo "❌ failed_units.txt does not exist yet (or is empty)"; exit 1; }
GOT=$(tr -d '\r' < failed_units.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')
WANT=$(cat .lm-state/want)
[ "$GOT" = "$WANT" ] && { echo "✅ failed_units.txt lists the $(echo "$WANT" | wc -l | tr -d ' ') units that failed, in boot order"; exit 0; }

if printf '%s\n' "$GOT" | grep -q $'\033\|\\[[0-9;]*m'; then
  echo "❌ failed_units.txt still contains colour escape codes; strip them (or match around them)"
  exit 1
fi
if [ -n "$(printf '%s\n' "$GOT" | sort | uniq -d)" ]; then
  echo "❌ a unit is listed more than once: a retry that fails again is still one unit"
  exit 1
fi
while IFS= read -r u; do
  printf '%s\n' "$WANT" | grep -qxF -- "$u" && continue
  if grep -q "Dependency failed for" sysroot/var/log/boot.log && grep -qiF -- "${u%.service}" <(grep 'Dependency failed' sysroot/var/log/boot.log); then
    echo "❌ '$u' only has a Dependency failed line: it was a consequence, not a failure of its own"
  elif grep -qF -- "failed to start" <<< "$u" || [[ "$u" == *" "* ]]; then
    echo "❌ '$u' is message text; list the unit name (see the line under each [FAILED] line)"
  else
    echo "❌ '$u' has no [FAILED] line in boot.log, or is not written as a unit name"
  fi
  exit 1
done <<< "$GOT"
if [ "$(printf '%s\n' "$GOT" | sort)" = "$(printf '%s\n' "$WANT" | sort)" ]; then
  echo "❌ the right units, in the wrong order: list them in the order they first failed during boot"
else
  n=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
  echo "❌ failed_units.txt has $n units, but more units than that failed; check every [FAILED] line"
fi
exit 1
