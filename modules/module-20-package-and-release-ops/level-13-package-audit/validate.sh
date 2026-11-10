#!/bin/bash
# drift.tsv must hold exactly the expected rows (any order), tab separated.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export LC_ALL=C
F=drift.tsv
if [ ! -s "$F" ]; then
  echo "❌ drift.tsv does not exist yet (or is empty)"
  exit 1
fi
if grep -q $'\r' "$F"; then
  echo "❌ drift.tsv contains carriage returns"
  exit 1
fi
n=$(awk -F '\t' 'NF != 3 || $1 == "" || $2 == "" || $3 == "" { print NR; exit }' "$F")
if [ -n "$n" ]; then
  echo "❌ drift.tsv line $n is not 'package<TAB>prod_version<TAB>staging_version' (three tab-separated fields)"
  exit 1
fi
if grep -qE ':[a-z0-9]+	' "$F"; then
  echo "❌ drift.tsv still has architecture suffixes (like :amd64) in package names"
  exit 1
fi
sort "$F" > .lm/got.sorted
sort .lm/drift.expected > .lm/want.sorted
if [ "$(uniq -d < .lm/got.sorted | wc -l)" -gt 0 ]; then
  echo "❌ drift.tsv lists the same row more than once"
  exit 1
fi
missing=$(comm -13 .lm/got.sorted .lm/want.sorted | wc -l)
extra=$(comm -23 .lm/got.sorted .lm/want.sorted | wc -l)
if [ "$missing" -ne 0 ] || [ "$extra" -ne 0 ]; then
  echo "❌ drift.tsv has $(wc -l < "$F") rows: $missing expected row(s) missing or wrong, $extra row(s) that should not be there"
  exit 1
fi
if ! sort -c "$F" 2>/dev/null; then
  echo "❌ the rows are right but not sorted by package name"
  exit 1
fi
echo "✅ drift.tsv lists all $(wc -l < "$F") differences between prod and staging"
