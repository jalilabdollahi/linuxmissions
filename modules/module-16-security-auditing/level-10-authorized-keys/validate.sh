#!/bin/bash
# Fingerprints in the file = original set minus the three leavers (matched by
# fingerprint, never by comment). Staying non-CI lines are unchanged. The CI key
# line has exactly: from="10.0.0.0/8", command="/usr/local/bin/deploy-only",
# no-port-forwarding, no-pty. ssh-keygen -lf must accept the file.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/stay ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -f authorized_keys ] || { echo "❌ authorized_keys is missing"; exit 1; }
if ! ssh-keygen -lf authorized_keys >/dev/null 2>&1; then
  echo "❌ ssh-keygen -lf cannot parse authorized_keys any more: a line is broken (quotes, commas or a missing key)"; exit 1
fi

fp_of() { printf '%s\n' "$1" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}'; }
seen=""
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  fp=$(fp_of "$line")
  [ -n "$fp" ] || { echo "❌ a line in authorized_keys is not a valid key"; exit 1; }
  if grep -qxF "$fp" .lm-state/leavers; then
    who=$(awk -v f="$fp" '{print}' offboard.txt | grep -F "$fp" | awk '{print $2}')
    echo "❌ the key of $who ($fp) is still in authorized_keys"; exit 1
  fi
  if [ -n "$(printf '%s\n' "$seen" | grep -xF "$fp")" ]; then echo "❌ a key appears twice in authorized_keys"; exit 1; fi
  seen="$seen
$fp"
  match=$(awk -F'\t' -v f="$fp" '$2 == f' .lm-state/stay)
  if [ -z "$match" ]; then echo "❌ authorized_keys contains a key that was not there before ($fp)"; exit 1; fi
  who=$(printf '%s\n' "$match" | cut -f1); orig=$(printf '%s\n' "$match" | cut -f3)
  if [ "$who" = ci ]; then
    ci_line=$line
  elif [ "$line" != "$orig" ]; then
    echo "❌ a key that should have stayed was modified (${orig##* })"; exit 1
  fi
done < authorized_keys
while IFS=$'\t' read -r who fp orig; do
  printf '%s\n' "$seen" | grep -qxF "$fp" || { echo "❌ the key of a person who is still here was removed (${orig##* })"; exit 1; }
done < .lm-state/stay

# options of the CI line: text before the key type, split at commas outside quotes
opts=$(printf '%s\n' "$ci_line" | sed -E 's/[[:space:]]+(ssh-ed25519|ssh-rsa|ecdsa-sha2-[a-z0-9]+)[[:space:]].*$//')
if [ "$opts" = "$ci_line" ]; then echo "❌ the CI key (ci-deploy@runner) has no restrictions yet"; exit 1; fi
list=$(printf '%s' "$opts" | awk '{ n = length($0); q = 0; cur = ""
  for (i = 1; i <= n; i++) { c = substr($0, i, 1)
    if (c == "\"") q = !q
    if (c == "," && !q) { print cur; cur = "" } else cur = cur c }
  print cur }')
has() { printf '%s\n' "$list" | tr 'A-Z' 'a-z' | grep -qxF -- "$1"; }
has 'no-port-forwarding' || { echo "❌ the CI key may still forward ports (add the option that forbids it)"; exit 1; }
has 'no-pty'             || { echo "❌ the CI key can still get a terminal (add the option that refuses a pty)"; exit 1; }
from=$(printf '%s\n' "$list" | grep -i '^from=' | head -1)
[ -n "$from" ] || { echo "❌ the CI key is not limited to an address range yet (from=)"; exit 1; }
[ "$from" = 'from="10.0.0.0/8"' ] || [ "$from" = 'FROM="10.0.0.0/8"' ] || { echo "❌ the from= option of the CI key is not the required network 10.0.0.0/8 ($from)"; exit 1; }
cmd=$(printf '%s\n' "$list" | grep -i '^command=' | head -1)
[ -n "$cmd" ] || { echo "❌ the CI key can still run any command (command=)"; exit 1; }
[ "$cmd" = 'command="/usr/local/bin/deploy-only"' ] || { echo "❌ the CI key's forced command is not /usr/local/bin/deploy-only ($cmd)"; exit 1; }
extra=$(printf '%s\n' "$list" | tr 'A-Z' 'a-z' | grep -vxF -e 'no-port-forwarding' -e 'no-pty' -e 'from="10.0.0.0/8"' -e 'command="/usr/local/bin/deploy-only"')
[ -z "$extra" ] || { echo "❌ the CI key has an option that is not part of the requirements: $(echo "$extra" | head -1)"; exit 1; }
echo "✅ the three leavers' keys are gone, everyone else is untouched and the CI key is locked to deploy-only from 10.0.0.0/8"
exit 0
