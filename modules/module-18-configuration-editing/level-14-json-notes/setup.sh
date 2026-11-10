#!/bin/bash
# flags.json: new_checkout and dark_mode both have an "eu" region (only new_checkout's
# must change), "testers" and "owners" are both arrays of strings. The original is
# kept in .lm-state so the validator can compute the expected result.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

pool=(ana-3 bo-7 chen-2 dara-9 eli-4 farid-1 gita-6 hugo-5)
t1=${pool[RANDOM % 8]}
t2=${pool[RANDOM % 8]}
while [ "$t2" = "$t1" ]; do t2=${pool[RANDOM % 8]}; done
pct=$((RANDOM % 40 + 10))

cat > flags.json <<JSON
{
  "version": 41,
  "flags": {
    "dark_mode": {
      "enabled": true,
      "regions": { "us": true, "eu": false, "apac": true }
    },
    "new_checkout": {
      "enabled": true,
      "rollout_percent": $pct,
      "regions": { "us": true, "eu": false, "apac": false }
    },
    "xmas_banner": {
      "enabled": false,
      "expires": "2025-12-31",
      "regions": { "us": false, "eu": false, "apac": false }
    },
    "search_v2": {
      "enabled": true,
      "regions": { "us": true, "eu": true, "apac": true }
    }
  },
  "testers": ["$t1", "$t2"],
  "owners": ["payments-team", "web-team"]
}
JSON
cp flags.json .lm-state/original.json
