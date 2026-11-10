#!/bin/bash
# preflight.sh has four gate checks and every one of them is broken in a
# different way: -f instead of -s, `[ $free > 500 ]` (a redirection that
# creates a file named 500), exclusive freeze boundaries, and an unquoted
# `[ ... -a ... ]` that errors out (status 2) and therefore never stops.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > preflight.sh <<'EOF'
#!/bin/bash
# preflight.sh - decides whether a deploy may go ahead. The pipeline runs
#   ./preflight.sh && ./deploy.sh
# Inputs (environment):
#   CONFIG       deploy config file             (default deploy.conf)
#   DF_FILE      `df -Pm /srv` capture          (default df.txt)
#   FREEZE_FILE  change freeze windows          (default freeze.conf)
#                lines "START END REASON...", dates YYYY-MM-DD, both days
#                included; lines starting with # and empty lines are ignored
#   TODAY        YYYY-MM-DD                     (default: today)
#   BRANCH       the branch being deployed
#   FORCE        FORCE=1 allows a branch other than main
# Checks, in this order; the first one that fails prints its line and exits 1:
#   STOP: config CONFIG is missing or empty
#   STOP: only N MB free on /srv (need 500)          (N under 500)
#   STOP: change freeze until END (REASON)
#   STOP: branch BRANCH is not main (set FORCE=1 to override)
# All good: "GO: deploying BRANCH", exit 0. Always exactly one line.

CONFIG=${CONFIG:-deploy.conf}
DF_FILE=${DF_FILE:-df.txt}
FREEZE_FILE=${FREEZE_FILE:-freeze.conf}
TODAY=${TODAY:-$(date +%F)}

stop() { echo "STOP: $*"; exit 1; }

# 1. a usable config
[ -f "$CONFIG" ] || stop "config $CONFIG is missing or empty"

# 2. enough disk space on /srv (4th column of the df line, in MB)
free=$(awk 'NR == 2 {print $4}' "$DF_FILE")
if [ $free > 500 ]; then
  :   # enough space
else
  stop "only $free MB free on /srv (need 500)"
fi

# 3. no change freeze today
while read -r start end reason; do
  case $start in '#'*|'') continue ;; esac
  if [ "$TODAY" \> "$start" ] && [ "$TODAY" \< "$end" ]; then
    stop "change freeze until $end ($reason)"
  fi
done < "$FREEZE_FILE"

# 4. only main, unless forced
if [ $BRANCH != main -a $FORCE != 1 ]; then
  stop "branch $BRANCH is not main (set FORCE=1 to override)"
fi

echo "GO: deploying $BRANCH"
EOF
chmod +x preflight.sh

printf '%s\n' 'service=billing-api' 'replicas=3' 'healthcheck=/healthz' > deploy.conf
cat > df.txt <<'EOF'
Filesystem     1048576-blocks   Used Available Capacity Mounted on
/dev/sdc1              503831 503771        60     100% /srv
EOF
cat > df-after-cleanup.txt <<'EOF'
Filesystem     1048576-blocks   Used Available Capacity Mounted on
/dev/sdc1              503831 485598     18233      97% /srv
EOF
cat > freeze.conf <<'EOF'
# change freezes (START END REASON), both days included
2026-11-26 2026-11-27 black friday
2026-12-20 2027-01-04 year-end freeze
EOF

cat > INCIDENT.txt <<'EOF'
INC-4471: deploy went out with 60 MB free on /srv, release unpacking failed
half-way. preflight.sh said GO. Same week: a feature branch was deployed to
production without FORCE=1, and nobody knows why a file called "500" keeps
appearing in the repo checkout.
Reproduce: BRANCH=feature/invoice-pdf ./preflight.sh; echo "exit $?"
EOF
