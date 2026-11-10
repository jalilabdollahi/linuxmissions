#!/bin/bash
# Query the shared mock sshd for four connections. Each effective setting list must
# equal the stored baseline with exactly three keywords changed: permitrootlogin no,
# passwordauthentication no, maxauthtries 3.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCK="$(cd "$(dirname "$0")/../../../mocks/security" && pwd)/sshd"
[ -s .lm-state/contexts ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -f etc/ssh/sshd_config ] || { echo "❌ etc/ssh/sshd_config is missing"; exit 1; }

if ! err=$(python3 "$MOCK" -t -f etc/ssh/sshd_config 2>&1); then
  echo "❌ sshd -t rejects the configuration: $(echo "$err" | head -1)"; exit 1
fi
want_line() {  # keyword -> required value
  case "$1" in permitrootlogin) echo no ;; passwordauthentication) echo no ;; maxauthtries) echo 3 ;; esac
}
i=0
while IFS= read -r c; do
  i=$((i + 1))
  if ! got=$(python3 "$MOCK" -T -f etc/ssh/sshd_config -C "$c" 2>&1); then
    echo "❌ sshd -T fails for $c: $(echo "$got" | head -1)"; exit 1
  fi
  user=${c#user=}; user=${user%%,*}; addr=${c##*addr=}
  for kw in permitrootlogin passwordauthentication maxauthtries; do
    have=$(printf '%s\n' "$got" | awk -v k="$kw" '$1 == k { print $2 }')
    if [ "$have" != "$(want_line $kw)" ]; then
      echo "❌ for user $user from $addr, $kw is effectively \"$have\" (sshd -T -C shows what sshd really uses)"; exit 1
    fi
  done
  # nothing else may have changed
  expected=$(sed -e 's/^permitrootlogin .*/permitrootlogin no/' -e 's/^passwordauthentication .*/passwordauthentication no/' \
                 -e 's/^maxauthtries .*/maxauthtries 3/' ".lm-state/baseline.$i")
  if [ "$got" != "$expected" ]; then
    d=$(diff <(printf '%s\n' "$expected") <(printf '%s\n' "$got") | grep '^[<>]' | head -1)
    echo "❌ another setting changed for user $user from $addr (${d:2}): only the three findings should be fixed"; exit 1
  fi
done < .lm-state/contexts
echo "✅ root login and passwords are off and MaxAuthTries is 3 for every connection, and nothing else moved"
exit 0
