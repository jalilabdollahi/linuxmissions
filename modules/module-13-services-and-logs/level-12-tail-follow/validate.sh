#!/bin/bash
# token.txt must hold the one-time admin token of a deploy the player
# triggered. The deploy agent stores only hashes of the tokens it issued and
# of the old ones its housekeeping revoked.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f .lm-state/issued.sha ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if ! pgrep -f "$SANDBOX/opt/deploy-agent/deploy-agent" >/dev/null; then
  echo "❌ the deploy agent isn't running any more; type 'reset' to start it again"
  exit 1
fi
if [ ! -f token.txt ]; then
  echo "❌ token.txt does not exist yet"
  exit 1
fi
toks=$(grep -o 'adm_[A-Za-z0-9]*' token.txt | sort -u)
if [ -z "$toks" ]; then
  echo "❌ token.txt holds no admin token (they look like adm_ followed by 24 letters and digits)"
  exit 1
fi
if [ "$(printf '%s\n' "$toks" | wc -l)" -ne 1 ]; then
  echo "❌ token.txt holds several different tokens; keep only the one from your deploy"
  exit 1
fi
h=$(printf '%s' "$toks" | sha256sum | cut -d' ' -f1)
if grep -qx "$h" .lm-state/revoked.sha 2>/dev/null; then
  echo "❌ $toks is an old token that housekeeping revoked; the one you want is printed during the deploy you trigger"
  exit 1
fi
if ! grep -qx "$h" .lm-state/issued.sha; then
  if [ ! -s .lm-state/issued.sha ]; then
    echo "❌ no deploy has run yet, so no token was printed: ./trigger-deploy.sh starts one"
  else
    echo "❌ $toks is not a token any deploy printed (24 letters and digits after adm_)"
  fi
  exit 1
fi
echo "✅ token.txt holds the one-time admin token, caught in the new deploy.log before it was scrubbed"
exit 0
