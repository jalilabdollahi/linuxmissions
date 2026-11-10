#!/bin/bash
# domains.txt = "count domain", sorted by count desc then domain (LC_ALL=C).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ "$(cksum < urls.txt 2>/dev/null)" != "$(cat .lm-state/urls.sum)" ]; then
  echo "❌ urls.txt was changed; type 'reset' to restore it"; exit 1
fi
if [ ! -f domains.txt ]; then echo "❌ domains.txt does not exist yet"; exit 1; fi

expect=$(mktemp "$SANDBOX/.lm-state/expect.XXXXXX"); got=$(mktemp "$SANDBOX/.lm-state/got.XXXXXX")
trap 'rm -f "$expect" "$got"' EXIT
awk '
NR == FNR { two[$1] = 1; next }
{
  u = tolower($0)
  sub(/^[a-z]+:\/\//, "", u); sub(/[\/?].*/, "", u); sub(/:[0-9]+$/, "", u); sub(/\.$/, "", u)
  n = split(u, a, ".")
  d = a[n - 1] "." a[n]
  if (d in two) d = a[n - 2] "." d
  c[d]++
}
END { for (d in c) print c[d], d }' two-level-suffixes.txt urls.txt | LC_ALL=C sort -k1,1nr -k2,2 > "$expect"
sed 's/^ *//' domains.txt > "$got"

if cmp -s "$got" "$expect"; then
  echo "✅ domains.txt: $(wc -l < "$expect" | tr -d ' ') domains, top one is $(head -1 "$expect")"
  exit 0
fi
if grep -qE ':[0-9]' "$got"; then echo "❌ some entries still contain a port (like $(grep -m1 ':[0-9]' "$got")): strip it before cutting labels"; exit 1; fi
if grep -q '/' "$got"; then echo "❌ some entries still contain a path ($(grep -m1 '/' "$got"))"; exit 1; fi
if grep -qE '[A-Z]' "$got"; then echo "❌ some domains are not lowercase ($(grep -m1 '[A-Z]' "$got"))"; exit 1; fi
if grep -qE '\.$' "$got"; then echo "❌ some domains end with a dot ($(grep -m1 '\.$' "$got"))"; exit 1; fi
bad=$(grep -vcE '^[0-9]+ [a-z0-9.-]+$' "$got")
if [ "$bad" -gt 0 ]; then echo "❌ $bad line(s) are not 'count domain' (for example: $(grep -vm1 -E '^[0-9]+ [a-z0-9.-]+$' "$got"))"; exit 1; fi
for s in $(cat two-level-suffixes.txt); do
  if grep -qE "^[0-9]+ $(printf '%s' "$s" | sed 's/\./\\./g')$" "$got"; then
    echo "❌ the entry '$(grep -m1 -E " $s$" "$got")' is only a suffix: names under $s need three labels"; exit 1
  fi
done
if [ "$(awk '{s += $1} END {print s}' "$got")" != "5000" ]; then
  echo "❌ the counts add up to $(awk '{s += $1} END {print s}' "$got"), not 5000: some requests were lost or counted twice"; exit 1
fi
if [ "$(wc -l < "$got")" -ne "$(wc -l < "$expect")" ]; then
  echo "❌ domains.txt has $(wc -l < "$got") domains, expected $(wc -l < "$expect") (some hosts are grouped wrongly)"; exit 1
fi
echo "❌ the domains and counts are right in size, but the order is wrong: highest count first, then byte order of the domain (LC_ALL=C)"
exit 1
