#!/bin/bash
# provision-wizard: six prompts ending in ":" and a space (no newline), asked in
# a random order (or the order in $LM_ORDER, a space-separated permutation of
# 0..5, which the validator sets). Answers are checked by format, so an answer
# given to the wrong prompt aborts the run. On success it writes
# provision.result (key=value, sorted).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
cat > provision-wizard <<'WIZ'
#!/bin/bash
# Server provisioning wizard 3.1 -- reads answers from stdin
rm -f provision.result
prompts=("Hostname for the new server:" "Region code (letters-letters-digit):" "Instance size (small, medium or large):" \
         "Really provision this server? [y/N]:" "Owner e-mail address:" "Environment (dev, stage or prod):")
keys=(hostname region size confirm owner env)
checks=('^[a-z]+-[0-9]+$' '^[a-z]+-[a-z]+-[0-9]$' '^(small|medium|large)$' '^(y|Y|yes)$' '^[^@ ]+@[^@ ]+$' '^(dev|stage|prod)$')
if [ -n "$LM_ORDER" ]; then order=($LM_ORDER); else order=($(shuf -e 0 1 2 3 4 5)); fi
echo "Server provisioning wizard 3.1"
echo "Answer each question and press Enter."
declare -A got
for i in "${order[@]}"; do
  printf '%s ' "${prompts[i]}"
  if ! read -r -t 4 ans; then echo "wizard: no answer, giving up" >&2; exit 1; fi
  if ! [[ $ans =~ ${checks[i]} ]]; then echo "wizard: '$ans' is not a valid answer for ${keys[i]}" >&2; exit 1; fi
  got[${keys[i]}]=$ans
done
for k in confirm env hostname owner region size; do echo "$k=${got[$k]}"; done > provision.result
echo "Provisioning request saved."
WIZ
chmod +x provision-wizard
cp provision-wizard .lm-state/provision-wizard
pick() { shuf -n 1 -e "$@"; }
host="$(pick web db cache queue edge batch)-$(printf '%02d' $((RANDOM % 90 + 1)))"
region="$(pick eu us ap sa)-$(pick west east north south central)-$((1 + RANDOM % 3))"
owner="$(pick ana ben carla dev eli)$(pick . _ -)$(pick lopez wu kim novak ito)@corp.example"
cat > answers.conf <<CONF
# answers for the nightly provisioning job (ticket OPS-$((1000 + RANDOM % 9000)))
hostname=$host
region=$region
size=$(pick small medium large)
owner=$owner
env=$(pick dev stage prod)
confirm=y
CONF
grep -v '^#' answers.conf | sort > .lm-state/expected
