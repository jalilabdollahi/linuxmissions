SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/conn_states.old ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s conn_states.sh ] || { echo "❌ conn_states.sh is missing or empty"; exit 1; }
if grep -v '^[[:space:]]*#' conn_states.sh | grep -qw netstat; then
  echo "❌ conn_states.sh still calls netstat"; exit 1
fi
# a netstat that fails loudly, in case it is called some indirect way
mkdir -p .lm-state/nonet
printf '#!/bin/sh\necho "netstat: removed" >&2\nexit 127\n' > .lm-state/nonet/netstat
chmod +x .lm-state/nonet/netstat
bad=""
for try in 1 2 3 4 5; do
  want=$(bash .lm-state/conn_states.old 2>/dev/null)
  got=$(PATH="$SANDBOX/.lm-state/nonet:$PATH" bash conn_states.sh 2>.lm-state/err)
  if [ "$want" = "$got" ]; then
    echo "✅ the ss-based conn_states.sh prints exactly what the netstat version did"
    exit 0
  fi
  bad=1
  sleep 0.3
done
if [ -s .lm-state/err ] && grep -q netstat .lm-state/err; then
  echo "❌ conn_states.sh still depends on netstat"; exit 1
fi
if [ -z "$got" ]; then echo "❌ conn_states.sh prints nothing"; exit 1; fi
if echo "$got" | grep -qiE '^State'; then
  echo "❌ the output still contains ss's header line as if it were a state"; exit 1
fi
diffline=$(diff <(echo "$want") <(echo "$got") | grep '^>' | head -1 | cut -c3-)
if [ -n "$diffline" ]; then
  echo "❌ output differs from the old script, e.g. you print '$diffline' where the old one printed something else (state names, counts or sort order)"
else
  echo "❌ output differs from the old script: a state the old one printed is missing"
fi
exit 1
