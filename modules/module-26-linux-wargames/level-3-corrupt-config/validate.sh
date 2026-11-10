#!/bin/bash
# ./app --check passes and the config is exactly last-good plus the ticket's
# two changes (structural compare, so duplicates resolved correctly).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected.json ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
if ! sha256sum -c --quiet .lm-state/sources.sum >/dev/null 2>&1; then
  echo "❌ config.json.last-good or TICKET.md was modified; they are the reference, restore them with 'reset'"; exit 1
fi
if [ ! -f config.json ]; then echo "❌ config.json is missing"; exit 1; fi
if ! out=$(./app --check 2>&1); then echo "❌ ./app --check still fails: $out"; exit 1; fi
if ! jq -e . config.json >/dev/null 2>&1; then echo "❌ the checker is happy but jq cannot parse config.json"; exit 1; fi
python3 - <<'PY'
import json, sys
def walk(a, b, p=""):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a: return p + "." + k + " (unexpected)"
            if k not in b: return p + "." + k + " (missing)"
            r = walk(a[k], b[k], p + "." + k)
            if r: return r
        return None
    return None if a == b else p
cur = json.load(open("config.json")); exp = json.load(open(".lm-state/expected.json"))
r = walk(cur, exp)
if r:
    print("❌ config.json parses and checks, but differs from last-good plus the ticket's changes at %s" % r); sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ config.json passes the check and equals last-good plus exactly the two ticketed changes"
