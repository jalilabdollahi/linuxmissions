#!/bin/bash
# Runs preflight.sh in 15 scenarios (fixture files selected through the env
# vars) and checks the exit status and the single output line of each. Fails
# if a file named 500 shows up (the `[ $x > 500 ]` redirection bug).
SANDBOX="$1"
SCRIPT="$SANDBOX/preflight.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ preflight.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/preflight.sh"
cd "$WORK" || exit 1
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

printf 'service=shop\n' > good.conf
: > empty.conf
dfcap() { printf '%s\n' 'Filesystem     1048576-blocks   Used Available Capacity Mounted on' \
  "/dev/mapper/vg-srv           2048 1000 $2 50% /srv" > "$1"; }
dfcap df-big.txt 72611
dfcap df-60.txt 60
dfcap df-1200.txt 1200
dfcap df-500.txt 500
dfcap df-499.txt 499
cat > freeze.txt <<'EOF'
# freezes

2026-12-20 2027-01-04 year-end freeze
   
2027-03-30 2027-03-30 datacenter move
EOF

# CONFIG | DF_FILE | TODAY | BRANCH | FORCE | exit | line
CASES=(
  "good.conf|df-big.txt|2026-11-10|main||0|GO: deploying main"
  "missing.conf|df-big.txt|2026-11-10|main||1|STOP: config missing.conf is missing or empty"
  "empty.conf|df-big.txt|2026-11-10|main||1|STOP: config empty.conf is missing or empty"
  "good.conf|df-60.txt|2026-11-10|main||1|STOP: only 60 MB free on /srv (need 500)"
  "good.conf|df-499.txt|2026-11-10|main||1|STOP: only 499 MB free on /srv (need 500)"
  "good.conf|df-1200.txt|2026-11-10|main||0|GO: deploying main"
  "good.conf|df-500.txt|2026-11-10|main||0|GO: deploying main"
  "good.conf|df-big.txt|2026-12-20|main||1|STOP: change freeze until 2027-01-04 (year-end freeze)"
  "good.conf|df-big.txt|2027-01-04|main||1|STOP: change freeze until 2027-01-04 (year-end freeze)"
  "good.conf|df-big.txt|2027-03-30|main||1|STOP: change freeze until 2027-03-30 (datacenter move)"
  "good.conf|df-big.txt|2027-01-05|main||0|GO: deploying main"
  "good.conf|df-big.txt|2026-11-10|feature/login||1|STOP: branch feature/login is not main (set FORCE=1 to override)"
  "good.conf|df-big.txt|2026-11-10|feature/login|1|0|GO: deploying feature/login"
  "good.conf|df-big.txt|2026-11-10|hotfix-9|yes|1|STOP: branch hotfix-9 is not main (set FORCE=1 to override)"
  "empty.conf|df-60.txt|2026-12-24|feature/x||1|STOP: config empty.conf is missing or empty"
  "good.conf|df-60.txt|2026-12-24|feature/x||1|STOP: only 60 MB free on /srv (need 500)"
  "good.conf|df-big.txt|2026-12-24|feature/x|1|1|STOP: change freeze until 2027-01-04 (year-end freeze)"
)

for c in "${CASES[@]}"; do
  IFS='|' read -r conf df today branch force want_code want_line <<< "$c"
  env_args=(CONFIG="$conf" DF_FILE="$df" FREEZE_FILE=freeze.txt TODAY="$today" BRANCH="$branch")
  label="CONFIG=$conf DF_FILE=$df TODAY=$today BRANCH=$branch"
  if [ -n "$force" ]; then env_args+=(FORCE="$force"); label="$label FORCE=$force"; fi
  $LIMIT env "${env_args[@]}" bash ./preflight.sh </dev/null >out 2>err
  code=$?
  if [ -e 500 ]; then
    echo "❌ running preflight.sh created a file named '500': inside [ ], > is a redirection, not 'greater than'"
    exit 1
  fi
  if [ "$code" != "$want_code" ] || [ "$(cat out)" != "$want_line" ]; then
    echo "❌ $label: got exit $code and '$(head -n 1 out)'$( [ -s err ] && echo " (error: $(head -n 1 err))"), expected exit $want_code and '$want_line'"
    exit 1
  fi
done

echo "✅ preflight.sh stops every unsafe deploy with the right reason and lets the good ones through (${#CASES[@]} scenarios)"
exit 0
