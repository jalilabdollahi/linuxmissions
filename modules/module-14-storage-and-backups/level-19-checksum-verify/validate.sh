#!/bin/bash
# Compares verify-report.txt, section by section, with the three expected lists.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f verify-report.txt ] || { echo "❌ verify-report.txt does not exist yet"; exit 1; }
if [ "$(cd restored && find . -type f -printf '%p %s %m %T@\n' | LC_ALL=C sort | sha256sum | cut -d' ' -f1)" != "$(cat .lm-state/tree)" ]; then
  echo "❌ restored/ was changed (files added, removed, chmod'ed or modified): this level only reports"
  exit 1
fi
tr -d '\r' < verify-report.txt | sed 's/[[:space:]]*$//' > .lm-state/rep
sec() { awk -v h="== $1 ==" '$0==h {on=1; next} /^== .* ==$/ {on=0} on && NF' .lm-state/rep | LC_ALL=C sort; }
for h in MISSING EXTRA CORRUPTED; do
  grep -qxF "== $h ==" .lm-state/rep || { echo "❌ verify-report.txt has no '== $h ==' header line"; exit 1; }
done
ok=1
for pair in "MISSING missing" "EXTRA extra" "CORRUPTED corrupt"; do
  set -- $pair
  got=$(sec "$1"); want=$(cat ".lm-state/$2")
  [ "$got" = "$want" ] && continue
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if grep -qxF -- "$p" .lm-state/noise; then
      echo "❌ $p is listed under $1, but only its permissions or timestamp changed: its content is intact, so it is not a problem for this report"; exit 1
    fi
  done <<< "$got"
  extra=$(comm -23 <(printf '%s\n' "$got") <(printf '%s\n' "$want") | head -1)
  miss=$(comm -13 <(printf '%s\n' "$got") <(printf '%s\n' "$want") | head -1)
  if [ -n "$extra" ]; then
    echo "❌ section $1: '$extra' does not belong there (a renamed file is missing under the old name AND extra under the new one)"
  else
    echo "❌ section $1 is incomplete: '$miss' is not listed"
  fi
  exit 1
done
echo "✅ the report lists the missing, extra and corrupted files exactly"
