#!/bin/bash
# git.internal must have exactly the keyscan keys (found with ssh-keygen -F, which
# understands hashed names); the IP alias must not keep an old key; every other
# original line is still there byte for byte and nothing unknown was added.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/keep ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -f known_hosts ] || { echo "❌ known_hosts is missing"; exit 1; }

blobs() {  # blobs HOST -> key blobs ssh-keygen finds for HOST
  ssh-keygen -F "$1" -f known_hosts 2>/dev/null | awk '!/^#/ && NF >= 3 { print $3 }' | LC_ALL=C sort -u
}
new=$(LC_ALL=C sort -u .lm-state/new-blobs)
got=$(blobs git.internal)
if [ -z "$got" ]; then echo "❌ known_hosts has no key for git.internal at all: ssh would ask about an unknown host"; exit 1; fi
for b in $got; do
  if grep -qxF "$b" .lm-state/old-blobs; then echo "❌ known_hosts still trusts an old key for git.internal"; exit 1; fi
done
if [ "$got" != "$new" ]; then
  if [ "$(echo "$got" | grep -c .)" -lt "$(echo "$new" | grep -c .)" ]; then
    echo "❌ git.internal is missing one of the new keys from keyscan.txt"
  else
    echo "❌ git.internal has a key that is not in keyscan.txt"
  fi
  exit 1
fi
for b in $(blobs "[10.4.0.7]:2222"); do
  if grep -qxF "$b" .lm-state/old-blobs; then
    echo "❌ the old key is still trusted under the alternate address [10.4.0.7]:2222"; exit 1
  fi
done
# every other original entry survives untouched
while IFS= read -r l; do
  if ! grep -qxF -- "$l" known_hosts; then echo "❌ an entry for another host was lost or modified (hashed entry starting ${l:0:20}...)"; exit 1; fi
done < .lm-state/keep
# nothing foreign: every line is a kept line, a comment, a blank, or carries a new key
extra=$(grep -vxFf .lm-state/keep known_hosts | grep -v '^[[:space:]]*\(#\|$\)' | awk '{print $3}' | grep -vxFf .lm-state/new-blobs)
if [ -n "$extra" ]; then echo "❌ known_hosts contains an entry that is neither an original one nor one of the new keys"; exit 1; fi
echo "✅ git.internal now has only its new keys, the alias is clean and the other $(wc -l < .lm-state/keep | tr -d ' ') entries are untouched"
exit 0
