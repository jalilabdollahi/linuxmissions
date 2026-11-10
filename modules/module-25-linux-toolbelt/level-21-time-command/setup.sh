#!/bin/bash
# reports/gen-<name>.sh x3. Which name gets which behaviour is random:
#   wait    : sleep 2 (real 2 s, almost no CPU)
#   cpu     : a 2 s busy loop in the shell
#   syscall : dd bs=1 over /dev/zero (millions of tiny read/write calls)
# Each script appends its name to .lm-state/runs so the validator knows it ran.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p reports .lm-state
: > .lm-state/runs
names=($(shuf -n 3 -e sales inventory payroll ledger audit churn))
classes=($(shuf -e wait cpu syscall))
: > .lm-state/class.expected
for i in 0 1 2; do
  n=${names[i]} c=${classes[i]}
  f=reports/gen-$n.sh
  {
    echo '#!/bin/bash'
    echo "# report generator: $n"
    echo 'echo "gen-'$n'" >> "$(dirname "$0")/../.lm-state/runs"'
    case $c in
      wait)    echo "sleep 2" ;;
      cpu)     echo 'end=$(( ${EPOCHREALTIME/./} + 2000000 ))'
               echo 'while (( ${EPOCHREALTIME/./} < end )); do :; done' ;;
      syscall) echo "dd if=/dev/zero of=/dev/null bs=1 count=5000000 2>/dev/null" ;;
    esac
    echo "echo \"report $n finished\""
  } > "$f"
  chmod +x "$f"
  echo "gen-$n.sh $c" >> .lm-state/class.tmp
  echo "$c" > ".lm-state/class.of.gen-$n.sh"
done
sort .lm-state/class.tmp > .lm-state/class.expected
rm -f .lm-state/class.tmp
