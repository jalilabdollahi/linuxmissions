#!/bin/bash
# Starts two background python processes with the sandbox path in their
# command lines: the worker (random APP_ENV and DB_HOST in its environment,
# plus look-alike variables) and worker-metrics (its own, different values).
# etc/worker.conf says production. Nothing else knows the real values.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/worker etc .lm-state
cat > opt/worker/worker.py <<'PY'
#!/usr/bin/env python3
# Stand-in for a job worker: it only sleeps. The interesting part is the
# environment it was started with.
import sys, time
print("worker started, config:", sys.argv[1:], flush=True)
while True:
    time.sleep(30)
PY
cp opt/worker/worker.py opt/worker/worker-metrics.py
EVALS=(staging qa preprod canary sandbox)
APP_ENV=${EVALS[RANDOM % ${#EVALS[@]}]}
DB_HOST="db-$APP_ENV-$((RANDOM % 9 + 1)).corp.internal"
cat > etc/worker.conf <<T
# worker configuration
app_env = production
db_host = db-prod-1.corp.internal
queue = jobs
concurrency = 4
T
cat > TICKET.md <<'T'
# worker is writing to the wrong database

etc/worker.conf says production, yet orders from the worker end up in the
staging database. Someone restarted it manually last night. Which APP_ENV
and DB_HOST is the running process really using?

Write them to worker_env.txt:
  APP_ENV=...
  DB_HOST=...
worker-metrics is a separate exporter and is not the process in question.
T
# the real worker: decoy variables with similar names come first
env -i PATH="$PATH" HOME="$HOME" LANG=C.UTF-8 \
    OLD_APP_ENV=production APP_ENV_FILE="$SANDBOX/etc/worker.conf" DB_HOSTNAME=db-prod-1 \
    APP_ENV="$APP_ENV" DB_HOST="$DB_HOST" DB_HOST_FALLBACK=db-prod-1.corp.internal \
    python3 "$SANDBOX/opt/worker/worker.py" --config "$SANDBOX/etc/worker.conf" >/dev/null 2>&1 &
echo $! > .lm-state/worker.pid
env -i PATH="$PATH" HOME="$HOME" LANG=C.UTF-8 APP_ENV=production DB_HOST=metrics-agg.corp.internal \
    python3 "$SANDBOX/opt/worker/worker-metrics.py" --port 9102 >/dev/null 2>&1 &
sleep 0.5
printf 'APP_ENV=%s\nDB_HOST=%s\n' "$APP_ENV" "$DB_HOST" > .lm-state/expected
