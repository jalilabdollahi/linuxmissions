#!/bin/bash
# Run answer.sh five times, the wizard asking in five different orders. Every
# run must end with provision.result equal to answers.conf (sorted).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
st=.lm-state
[ -f answer.sh ] || { echo "❌ answer.sh does not exist yet"; exit 1; }
cmp -s provision-wizard $st/provision-wizard || { echo "❌ provision-wizard was modified; the script must work with the original"; exit 1; }
grep -v '^#' answers.conf | sort | cmp -s - $st/expected || { echo "❌ answers.conf was modified"; exit 1; }
run=0
for order in "0 1 2 3 4 5" "5 4 3 2 1 0" "3 0 5 1 4 2" "2 5 0 4 1 3" "4 2 1 5 0 3"; do
  run=$((run + 1))
  rm -f provision.result
  start=$SECONDS
  out=$(LM_ORDER="$order" timeout 10 bash answer.sh 2>&1 < /dev/null); rc=$?
  took=$((SECONDS - start))
  if [ "$rc" -eq 124 ] || [ "$took" -ge 10 ]; then
    echo "❌ run $run (question order: $order) did not finish within 10 seconds: is it waiting for a newline that never comes?"; exit 1
  fi
  if [ ! -f provision.result ]; then
    echo "❌ run $run (question order: $order) left no provision.result. Wizard said: $(echo "$out" | grep -a 'wizard:' | tail -1 | cut -c1-120)"; exit 1
  fi
  if ! cmp -s provision.result $st/expected; then
    echo "❌ run $run (question order: $order): provision.result does not match answers.conf"; exit 1
  fi
done
echo "✅ answer.sh completed the wizard in 5 different question orders"
exit 0
