#!/bin/bash
# leaks.txt must hold exactly the file:line of every real credential. repo/ must not be
# edited (line numbers would shift).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -s leaks.txt ] || { echo "❌ leaks.txt is missing or empty"; exit 1; }
if ! find repo -type f | LC_ALL=C sort | xargs sha256sum 2>/dev/null | cmp -s - .lm-state/tree.sha; then
  echo "❌ something under repo/ was changed or removed: this is an audit, only write leaks.txt"; exit 1
fi
# keep the first two colon-separated fields of every line (so raw grep -n output also works)
sed -e 's/\r$//' -e "s#^$SANDBOX/##" -e 's#^\./##' leaks.txt | grep -v '^[[:space:]]*$' | cut -d: -f1,2 | LC_ALL=C sort -u > .lm-state/got
bad=$(grep -vE '^[^:]+:[0-9]+$' .lm-state/got | head -1)
[ -z "$bad" ] || { echo "❌ leaks.txt line \"$bad\" is not in file:line form"; exit 1; }
extra=$(comm -13 .lm-state/expected .lm-state/got | head -1)
[ -z "$extra" ] || { echo "❌ leaks.txt lists $extra, but that is not a real credential (or the line number is wrong)"; exit 1; }
want=$(wc -l < .lm-state/expected); have=$(comm -12 .lm-state/expected .lm-state/got | wc -l)
[ "$have" -eq "$want" ] || { echo "❌ leaks.txt has $have of $want leaks: some are still hidden (hidden folders? compressed files?)"; exit 1; }
echo "✅ all $want leaks found and no false alarms"
exit 0
