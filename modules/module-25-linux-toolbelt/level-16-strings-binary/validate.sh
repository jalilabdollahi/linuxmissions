#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
st=.lm-state
[ -f findings.txt ] || { echo "❌ findings.txt does not exist yet"; exit 1; }
if cmp -s findings.txt $st/expected; then
  echo "✅ findings.txt has the real endpoint and the real licence ID"; exit 0
fi
url=$(sed -n 's/^endpoint=//p' $st/expected)
lic=$(sed -n 's/^license=//p' $st/expected)
if [ "$(wc -l < findings.txt)" -ne 2 ]; then
  echo "❌ findings.txt must have exactly two lines (endpoint=... and license=...), it has $(wc -l < findings.txt)"; exit 1
fi
if grep -q "$(cat $st/decoy_lic)" findings.txt; then
  echo "❌ the license value comes from the TEST block: it is a fixture, not the real licence"; exit 1
fi
if grep -qE '127\.0\.0\.1|example\.test' findings.txt; then
  echo "❌ the endpoint comes from the TEST block: it is a fixture, not the real one"; exit 1
fi
grep -qxF "endpoint=$url" findings.txt || { echo "❌ the endpoint line is not right (format endpoint=<url>, the URL the agent really reports to)"; exit 1; }
grep -qxF "license=$lic" findings.txt || { echo "❌ the license line is not right (format license=<id>; it is not stored the way the URL is)"; exit 1; }
echo "❌ findings.txt has the right values, but not as the two lines endpoint=... then license=..."; exit 1
