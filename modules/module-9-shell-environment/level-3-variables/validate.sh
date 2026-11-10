#!/bin/bash
# Runs a copy of name-report.sh in a clean directory with ENV/DAY values the
# player has not seen, then checks the file name and the report header.
SANDBOX="$1"
SCRIPT="$SANDBOX/name-report.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ name-report.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

envs=(staging prod-eu qa3 canary perf-lab)
ENVV="${envs[$(( RANDOM % 5 ))]}$(( RANDOM % 9 + 1 ))"
DAYV="2026-0$(( RANDOM % 9 + 1 ))-$(printf '%02d' $(( RANDOM % 28 + 1 )))"
TODAY="$(date +%F)"

# run LABEL ENV=.. [DAY=..]  -> sets GOT (files created in reports/)
run() {
  rm -rf "$WORK/run"; mkdir "$WORK/run"; cp "$SCRIPT" "$WORK/run/name-report.sh"
  (cd "$WORK/run" && $LIMIT env -i PATH="$PATH" HOME="$WORK" "$@" bash ./name-report.sh </dev/null >/dev/null 2>"$WORK/err")
  GOT="$(cd "$WORK/run" && ls reports 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
}

# check WHAT EXPECTED-DAY
check() {
  want="report-${ENVV}_$2.txt"
  if [ "$GOT" != "$want" ]; then
    if [ -z "$GOT" ]; then
      echo "❌ $1: the script created no report at all ($(head -1 "$WORK/err"))"
    elif [ "$GOT" = "report-$2.txt" ] || [ "$GOT" = "report-.txt" ]; then
      echo "❌ $1: the file is reports/$GOT, the environment is missing from the name (which variable does \$ENV_ refer to?)"
    elif [ "$GOT" = "report-${ENVV}_.txt" ]; then
      echo "❌ $1: the file is reports/$GOT, the day is missing"
    else
      echo "❌ $1: got reports/$GOT, expected reports/$want"
    fi
    exit 1
  fi
  f="$WORK/run/reports/$want"
  if ! grep -qxF "environment: $ENVV" "$f" || ! grep -qxF "day: $2" "$f"; then
    echo "❌ $1: the file name is right, but the report's 'environment:' / 'day:' lines don't show $ENVV and $2"
    exit 1
  fi
}

run ENV="$ENVV" DAY="$DAYV"
check "with ENV=$ENVV DAY=$DAYV" "$DAYV"
run ENV="$ENVV"
check "with ENV=$ENVV and DAY unset (as cron runs it)" "$TODAY"
run ENV="$ENVV" DAY=
check "with ENV=$ENVV and DAY set but empty" "$TODAY"

echo "✅ name-report.sh names its reports report-<ENV>_<DAY>.txt and falls back to today's date"
exit 0
