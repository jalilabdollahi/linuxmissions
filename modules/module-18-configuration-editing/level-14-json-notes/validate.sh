#!/bin/bash
# Apply the three requested changes to the saved original in Python (which keeps key
# order) and compare with the player's file, both as data and as key order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f flags.json ]; then
  echo "❌ flags.json is missing"
  exit 1
fi
if [ ! -s flags.json ]; then
  echo "❌ flags.json is empty: the redirection truncated it before jq could read it"
  exit 1
fi

python3 - <<'PY'
import json, sys

try:
    got = json.load(open("flags.json"))
except ValueError as e:
    print(f"❌ flags.json is not valid JSON any more: {e}")
    sys.exit(1)
want = json.load(open(".lm-state/original.json"))
want["flags"]["new_checkout"]["regions"]["eu"] = True
want["testers"].append("beta-12")
del want["flags"]["xmas_banner"]

if got == json.load(open(".lm-state/original.json")):
    print("❌ flags.json has not been changed yet")
    sys.exit(1)
flags = got.get("flags", {}) if isinstance(got, dict) else {}
if "xmas_banner" in flags:
    print("❌ xmas_banner is still in flags")
    sys.exit(1)
if flags.get("new_checkout", {}).get("regions", {}).get("eu") is not True:
    print("❌ new_checkout is not enabled for the eu region yet")
    sys.exit(1)
if "beta-12" not in got.get("testers", []):
    print("❌ beta-12 is not in the testers array")
    sys.exit(1)
if got["testers"].count("beta-12") != 1:
    print("❌ beta-12 is in testers more than once")
    sys.exit(1)
if got != want:
    names = []
    for k in sorted(set(got) | set(want)):
        if got.get(k) != want.get(k):
            names.append(k)
    print("❌ something besides the three requested changes differs (top-level: " + ", ".join(names) + ")")
    sys.exit(1)
if json.dumps(got) != json.dumps(want):
    print("❌ the data is right, but the key order of the file changed")
    sys.exit(1)
print("✅ eu rollout on, beta-12 added, xmas_banner gone, the rest untouched and in order")
PY
