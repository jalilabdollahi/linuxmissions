#!/bin/bash
# audit.tsv (category<TAB>path<TAB>detail) must equal the expected finding set, categories taken
# from categories.txt, and host/ must be exactly as it was (modes, types and contents).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -s audit.tsv ] || { echo "❌ audit.tsv is missing or empty"; exit 1; }
now=$( ( find host -printf '%p %y %m\n'; find host -type f -exec sha256sum {} + ) | LC_ALL=C sort )
[ "$now" = "$(cat .lm-state/tree)" ] || { echo "❌ something under host/ was changed: this audit is read-only, only write audit.tsv"; exit 1; }
sed -e 's/\r$//' -e "s#\t$SANDBOX/#\t#" -e 's#\t\./#\t#' audit.tsv | grep -v '^[[:space:]]*$' | LC_ALL=C sort -u > .lm-state/got
bad=$(awk -F'\t' 'NF != 3' .lm-state/got | head -1)
[ -z "$bad" ] || { echo "❌ \"$bad\" does not have three tab-separated fields (category, path, detail)"; exit 1; }
cat=$(awk -F'\t' 'NR == FNR { ok[$1] = 1; next } !($1 in ok) { print $1; exit }' categories.txt .lm-state/got)
[ -z "$cat" ] || { echo "❌ \"$cat\" is not one of the categories in categories.txt"; exit 1; }
extra=$(comm -13 .lm-state/expected .lm-state/got | head -1)
[ -z "$extra" ] || { echo "❌ audit.tsv has a finding that is wrong or not a finding under policy.txt: $(echo "$extra" | awk -F'\t' '{print $1 ": " $2 " (" $3 ")"}')"; exit 1; }
missing=$(comm -23 .lm-state/expected .lm-state/got)
if [ -n "$missing" ]; then
  n=$(echo "$missing" | wc -l)
  echo "❌ audit.tsv misses $n finding(s), for example in category $(echo "$missing" | head -1 | cut -f1)"; exit 1
fi
echo "✅ $(wc -l < .lm-state/expected) findings, all of them real, and nothing on the host was touched"
exit 0
