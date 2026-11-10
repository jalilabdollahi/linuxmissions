#!/bin/bash
# Reference solution: flock -n on a lock file next to the script, a loop over
# checks.d/* that skips anything that is not an executable regular file,
# timeout + retry with growing delays, the summary built in a temp file and
# moved into place at the end (removed by a trap if the run dies).
cat > run_checks.sh <<'SCRIPT'
#!/bin/bash
# run_checks.sh - nightly health checks (see SPEC.txt)
cd "$(dirname "$0")" || exit 1
CHECK_TIMEOUT="${CHECK_TIMEOUT:-10}"
RETRY_DELAY="${RETRY_DELAY:-2}"
MAX_ATTEMPTS=3

exec 9> run_checks.lock
if ! flock -n 9; then
  echo "run_checks: another run holds run_checks.lock, not starting" >&2
  exit 75
fi

tmp=$(mktemp summary.txt.XXXXXX)
trap 'rm -f "$tmp"' EXIT
mkdir -p logs
failed=0
total=0
for check in checks.d/*; do
  [ -f "$check" ] && [ -x "$check" ] || continue
  name=${check##*/}
  total=$((total + 1))
  attempt=1
  while :; do
    timeout "$CHECK_TIMEOUT" "$check" >> "logs/$name.log" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
      status=PASS
      break
    elif [ "$rc" -eq 124 ]; then
      status=TIMEOUT
    else
      status=FAIL
    fi
    [ "$attempt" -ge "$MAX_ATTEMPTS" ] && break
    sleep $(( RETRY_DELAY * attempt ))
    attempt=$((attempt + 1))
  done
  [ "$status" = PASS ] || failed=$((failed + 1))
  printf '%s %s %d\n' "$name" "$status" "$attempt" >> "$tmp"
done
printf 'failed %d of %d\n' "$failed" "$total" >> "$tmp"
mv "$tmp" summary.txt
exit "$failed"
SCRIPT
CHECK_TIMEOUT=1 RETRY_DELAY=1 ./run_checks.sh
echo "exit $?"
cat summary.txt
