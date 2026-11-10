#!/bin/bash
# Nightly Runner: the capstone. run_checks.sh must run every executable in
# checks.d/ with a timeout, retry failures with backoff, refuse to run twice
# at once (flock), write summary.txt in a fixed format and exit with the
# number of failed checks. The shipped checks include a hanging one, a flaky
# one, a README and a helper directory that must not be run.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p checks.d/lib queue state

cat > checks.d/10-disk-space <<'CHECK'
#!/bin/bash
# fails when the filesystem of the current directory is more than 95 % full
use=$(df -P . | awk 'NR == 2 { sub(/%/, "", $5); print $5 }')
echo "disk usage ${use}%"
[ "$use" -le 95 ]
CHECK

cat > checks.d/20-queue-depth <<'CHECK'
#!/bin/bash
# fails when more than 500 jobs are waiting
depth=$(cat queue/depth 2>/dev/null || echo 0)
if [ "$depth" -gt 500 ]; then
  echo "queue depth $depth > 500" >&2
  exit 2
fi
echo "queue depth $depth"
CHECK
echo 950 > queue/depth

cat > checks.d/30-api-health <<'CHECK'
#!/bin/bash
# the API's first answer after a quiet night is often a 503; the second is fine
n=$(cat state/api-tries 2>/dev/null || echo 0)
n=$((n + 1))
if [ "$n" -lt 2 ]; then
  echo "$n" > state/api-tries
  echo "GET /health -> 503 Service Unavailable" >&2
  exit 1
fi
rm -f state/api-tries
echo "GET /health -> 200 OK"
CHECK

cat > checks.d/40-nfs-mount <<'CHECK'
#!/bin/bash
# stat on a dead NFS mount never returns (here: it sleeps for 5 minutes)
echo "checking /mnt/shared"
exec sleep 300
CHECK

cat > checks.d/lib/common.sh <<'CHECK'
# helpers that checks may source; not a check itself
say() { echo "[check] $*"; }
CHECK

cat > checks.d/README.md <<'TXT'
Every executable file in this folder is one health check: exit 0 = healthy.
Helpers live in lib/. This README is not a check.
TXT
chmod +x checks.d/10-disk-space checks.d/20-queue-depth checks.d/30-api-health checks.d/40-nfs-mount

cat > run_checks.sh <<'SCRIPT'
#!/bin/bash
# run_checks.sh - nightly health checks (first draft)
for c in checks.d/*; do
  if $c; then
    echo "$c OK"
  else
    echo "$c FAILED"
  fi
done > summary.txt
SCRIPT
chmod +x run_checks.sh

cat > SPEC.txt <<'TXT'
run_checks.sh  (cron: 02:00 every night, started from this folder)

- Runs every executable regular file directly in checks.d/, in name order.
  Anything else there (README.md, the lib/ folder, files without x) is not
  a check: skip it, don't count it.
- Every attempt is limited to CHECK_TIMEOUT seconds (default 10).
- A check that fails or times out is retried, at most 3 attempts in total.
  Before the 2nd attempt wait RETRY_DELAY seconds (default 2), before the
  3rd attempt 2 x RETRY_DELAY.
- Only one run at a time: when another run_checks.sh holds the lock file
  run_checks.lock (next to the script), exit with status 75 immediately,
  without touching summary.txt.
- summary.txt, one line per check, then a total:
      <name> <PASS|FAIL|TIMEOUT> <attempts used>
      failed <n> of <total>
  TIMEOUT when the last attempt was stopped by the timeout, FAIL when it
  exited non-zero, PASS as soon as an attempt exits 0.
- Exit status: the number of checks that did not pass (0 = all healthy).

Quick test run here:  CHECK_TIMEOUT=2 RETRY_DELAY=1 ./run_checks.sh; echo $?; cat summary.txt
TXT
