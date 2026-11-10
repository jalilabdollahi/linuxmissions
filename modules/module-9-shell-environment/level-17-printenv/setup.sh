#!/bin/bash
# Ghost Config: a running worker got its DB_HOST/QUEUE/POOL at start time (random
# values that exist only in its environment). worker.env was fixed afterwards,
# but the worker was never restarted. A worker-metrics sidecar (restarted after
# the fix) is a decoy that also matches `pgrep -f worker`.
# Linux only: the player reads /proc/<pid>/environ.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin

cat > bin/worker <<'EOF'
#!/bin/bash
# worker - takes jobs from $QUEUE and writes results to the database at $DB_HOST,
# with $POOL connections. Settings come from the environment at start time.
while :; do
  sleep 2
done
EOF
cat > bin/worker-metrics <<'EOF'
#!/bin/bash
# worker-metrics - exports queue and pool metrics for the dashboards.
while :; do
  sleep 3
done
EOF
chmod +x bin/worker bin/worker-metrics

hex() { printf '%04x' $RANDOM; }
queues=(invoices payouts emails exports webhooks)
old_host="pg-$(hex).legacy.internal"
new_host="pg-$(hex).prod.internal"
live_queue="jobs-${queues[$(( RANDOM % 5 ))]}-$(( 1 + RANDOM % 9 ))"
live_pool=$(( 5 + RANDOM % 30 ))
if [ $(( RANDOM % 2 )) -eq 0 ]; then file_queue="$live_queue"; else file_queue="jobs-${queues[$(( RANDOM % 5 ))]}-$(( 10 + RANDOM % 9 ))"; fi
if [ $(( RANDOM % 2 )) -eq 0 ]; then file_pool="$live_pool"; else file_pool=$(( live_pool + 5 + RANDOM % 20 )); fi

cat > worker.env <<EOF
# worker.env - read by the init script when the worker starts.
# 2026-11-09: moved to the new primary (CHG-3318). Worker restart pending.
DB_HOST=$new_host
QUEUE=$file_queue
POOL=$file_pool
EOF
chmod 444 worker.env

# Started before the fix: the old values live only in this process's environment.
env DB_HOST="$old_host" QUEUE="$live_queue" POOL="$live_pool" \
  bash "$SANDBOX/bin/worker" >/dev/null 2>&1 &
# The sidecar was restarted after the fix and has the new values.
env DB_HOST="$new_host" QUEUE="$file_queue" POOL="$file_pool" METRICS_PORT=9187 \
  bash "$SANDBOX/bin/worker-metrics" >/dev/null 2>&1 &

cat > TICKET.txt <<'EOF'
INC-5120  worker still writes to the legacy database
----------------------------------------------------
worker.env was fixed yesterday (CHG-3318), but the DBA still sees
connections from the worker on the legacy primary. Before anyone restarts
anything, document what the RUNNING worker process (bin/worker) actually uses:

  live.env   its DB_HOST, QUEUE and POOL, one KEY=value per line
  stale.txt  the names of the keys whose live value differs from worker.env,
             one per line
EOF
