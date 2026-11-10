#!/bin/bash
# Set -e Was On: deploy.sh has `set -e`, yet a failed migration went live.
# set -e ignores failures in three places the script uses: the left side of
# an && list, everything inside a function called as an `if` condition, and a
# command substitution used as an argument of another command.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin

cat > bin/step <<'MOCK'
#!/bin/bash
# step NAME - runs one deploy step (stand-in) and records it in steps.log.
# FAIL_STEP=NAME makes that step fail, the way it failed in production.
name="$1"
echo "$name" >> steps.log
if [ "${FAIL_STEP:-}" = "$name" ]; then
  case "$name" in
    migrate) echo "migrate: ERROR 1146: table 'orders_v2' doesn't exist" >&2 ;;
    verify)  echo "verify: 3 of 12 smoke tests FAILED" >&2 ;;
    *)       echo "$name: FAILED" >&2 ;;
  esac
  exit 1
fi
case "$name" in
  verify) echo "12 of 12 smoke tests passed" ;;
  *)      echo "$name: ok" ;;
esac
MOCK
chmod +x bin/step

cat > deploy.sh <<'SCRIPT'
#!/bin/bash
# deploy.sh - ship the current release.
# Steps, in order: fetch, build, migrate, schema-version, verify, deploy.
# Each one runs through ./bin/step. Any failing step must stop the deploy.
set -e

log() { echo "[deploy] $*"; }

run_migrations() {
  ./bin/step migrate
  ./bin/step schema-version
}

./bin/step fetch && log "release fetched"
./bin/step build
if run_migrations; then
  log "migrations applied"
else
  log "migrations FAILED, stopping" >&2
  exit 1
fi
log "smoke test: $(./bin/step verify)"
./bin/step deploy
log "release is live"
SCRIPT
chmod +x deploy.sh

cat > POSTMORTEM.txt <<'TXT'
Release 4.12, 23:10. migrate failed with "table 'orders_v2' doesn't exist".
deploy.sh printed "migrations applied", ran the remaining steps and put the
release live on a half-migrated database. The script HAS `set -e` at the top.

Replay it (each run appends to steps.log; delete it between runs):
  rm -f steps.log; FAIL_STEP=migrate ./deploy.sh; echo "exit $?"; cat steps.log
Other steps that have failed before: fetch, verify.
TXT
