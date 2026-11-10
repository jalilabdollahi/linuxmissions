#!/bin/bash
# Reference solution: keep set -e, but stop relying on it where bash ignores
# it: no && list for fetch, an explicit `|| return` inside the function that is
# called from `if`, and the verify output captured in its own assignment.
cat > deploy.sh <<'SCRIPT'
#!/bin/bash
# deploy.sh - ship the current release.
# Steps, in order: fetch, build, migrate, schema-version, verify, deploy.
# Each one runs through ./bin/step. Any failing step must stop the deploy.
set -e

log() { echo "[deploy] $*"; }

run_migrations() {
  ./bin/step migrate || return 1
  ./bin/step schema-version || return 1
}

./bin/step fetch
log "release fetched"
./bin/step build
if run_migrations; then
  log "migrations applied"
else
  log "migrations FAILED, stopping" >&2
  exit 1
fi
smoke=$(./bin/step verify)
log "smoke test: $smoke"
./bin/step deploy
log "release is live"
SCRIPT
rm -f steps.log
FAIL_STEP=migrate ./deploy.sh
echo "exit $?"
cat steps.log
rm -f steps.log
