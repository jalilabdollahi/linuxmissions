#!/bin/bash
# missing.txt = modules in healthy but not in broken; load_first.txt = the missing
# module that no other missing module uses (computed from the two captures).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cksum healthy.lsmod broken.lsmod 2>/dev/null | cmp -s - .lm-state/sums; then
  echo "❌ a lsmod capture was changed; type 'reset' to get them back"
  exit 1
fi
for f in missing.txt load_first.txt; do
  [ -s "$f" ] || { echo "❌ $f does not exist yet (or is empty)"; exit 1; }
done
names() { awk 'NR > 1 { print $1 }' "$1" | LC_ALL=C sort; }
WANT=$(LC_ALL=C comm -23 <(names healthy.lsmod) <(names broken.lsmod))
clean() { tr -d '\r' < "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$'; }
GOT=$(clean missing.txt | LC_ALL=C sort)
if [ "$GOT" != "$WANT" ]; then
  extra=$(LC_ALL=C comm -13 <(printf '%s\n' "$WANT") <(printf '%s\n' "$GOT") | head -1)
  if [ -n "$extra" ]; then
    if grep -q "^$extra " broken.lsmod; then
      echo "❌ missing.txt lists $extra, but it is loaded on the broken host too"
    else
      echo "❌ missing.txt lists '$extra', which is not a module of the healthy twin"
    fi
  else
    echo "❌ missing.txt has $(printf '%s\n' "$GOT" | wc -l | tr -d ' ') modules, but more are missing on the broken host"
  fi
  exit 1
fi
# load_first: missing module not listed in the Used-by column of another missing module.
FIRST=$(printf '%s\n' "$WANT" | while read -r m; do
  users=$(awk -v m="$m" 'NR > 1 && $1 == m { print $4 }' healthy.lsmod | tr ',' '\n')
  inside=$(printf '%s\n' "$users" | grep -xF -f <(printf '%s\n' "$WANT") || true)
  [ -z "$inside" ] && echo "$m"
done)
LF=$(clean load_first.txt)
if [ "$(printf '%s\n' "$LF" | wc -l)" -ne 1 ]; then
  echo "❌ load_first.txt must hold exactly one module name"
  exit 1
fi
if [ "$LF" != "$FIRST" ]; then
  if printf '%s\n' "$WANT" | grep -qxF -- "$LF"; then
    by=$(awk -v m="$LF" '$1 == m { print $4 }' healthy.lsmod)
    echo "❌ $LF is used by $by in the healthy capture: so it sits below them in the stack; the module you want is not used by any other missing module"
  else
    echo "❌ load_first.txt must name one of the missing modules"
  fi
  exit 1
fi
echo "✅ $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') modules are missing and loading $FIRST brings back the whole stack"
exit 0
