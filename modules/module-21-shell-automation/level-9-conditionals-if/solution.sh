#!/bin/bash
# Fix the four conditions: -s, a numeric -lt, inclusive date bounds with
# [[ ]], and a quoted, two-test branch check.
cat > preflight.sh <<'SCRIPT'
#!/bin/bash
# preflight.sh - decides whether a deploy may go ahead (see INCIDENT.txt).
CONFIG=${CONFIG:-deploy.conf}
DF_FILE=${DF_FILE:-df.txt}
FREEZE_FILE=${FREEZE_FILE:-freeze.conf}
TODAY=${TODAY:-$(date +%F)}

stop() { echo "STOP: $*"; exit 1; }

[ -s "$CONFIG" ] || stop "config $CONFIG is missing or empty"

free=$(awk 'NR == 2 {print $4}' "$DF_FILE")
if [ "$free" -lt 500 ]; then
  stop "only $free MB free on /srv (need 500)"
fi

while read -r start end reason; do
  case $start in '#'*|'') continue ;; esac
  if [[ ! $TODAY < $start && ! $TODAY > $end ]]; then
    stop "change freeze until $end ($reason)"
  fi
done < "$FREEZE_FILE"

if [[ $BRANCH != main && $FORCE != 1 ]]; then
  stop "branch $BRANCH is not main (set FORCE=1 to override)"
fi

echo "GO: deploying $BRANCH"
SCRIPT
rm -f 500
BRANCH=feature/invoice-pdf ./preflight.sh; echo "exit $?"
