#!/bin/bash
# Runs nightly_export.sh four times in scratch copies, each with its own empty
# TMPDIR and with mock fetch_orders/to_csv that record their PID:
#   1. a normal run            -> exit 0, the new export.csv, nothing left over
#   2. to_csv fails            -> exit non-zero, yesterday's export.csv intact
#   3. TERM after 1 s          -> exit 143 within 3 s, fetch step stopped
#   4. export.lock is present  -> exit non-zero, the other run's lock untouched
# After every run: no export.lock (except case 4), TMPDIR empty, no stray files.
SANDBOX="$1"
SCRIPT="$SANDBOX/nightly_export.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ nightly_export.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
cleanup_all() {
  for p in "$WORK"/*/.fetch.pid; do
    [ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null
  done
  rm -rf "$WORK"
}
trap cleanup_all EXIT

YESTERDAY="order_id,customer,amount
39001,C1041,977.11
39002,C1082,1954.12"

# fresh NAME: a scratch copy in $R with mocks, yesterday's export and an empty TMPDIR
fresh() {
  R="$WORK/$1"
  mkdir -p "$R/bin" "$R/tmp"
  cp "$SCRIPT" "$R/nightly_export.sh"
  printf '%s\n' "$YESTERDAY" > "$R/export.csv"
  cat > "$R/bin/fetch_orders" <<'MOCK'
#!/bin/bash
echo $$ > .fetch.pid
echo "order_id|customer|amount"
n="${FETCH_ROWS:-300}"
i=1
while [ "$i" -le "$n" ]; do
  sleep 0.1
  echo "$((50000 + i))|K$((i * 53 % 97))|$((i * 211 % 700)).$((10 + i % 80))"
  i=$((i + 1))
done
MOCK
  cat > "$R/bin/to_csv" <<'MOCK'
#!/bin/bash
n=0
while IFS='|' read -r id cust amount; do
  if [ -n "${TO_CSV_FAIL_AT:-}" ] && [ "$n" -ge "$TO_CSV_FAIL_AT" ]; then
    echo "to_csv: malformed row $((n + 1))" >&2
    exit 1
  fi
  echo "$id,$cust,$amount"
  n=$((n + 1))
done
MOCK
  chmod +x "$R/bin/fetch_orders" "$R/bin/to_csv"
}

# leftovers WHAT: nothing may be left behind by run WHAT
leftovers() {
  if [ -e "$R/export.lock" ] && [ "$1" != "when export.lock already existed" ]; then
    echo "❌ $1, export.lock was left behind"
    exit 1
  fi
  if [ -n "$(ls -A "$R/tmp")" ]; then
    echo "❌ $1, the temp directory was left behind in \$TMPDIR ($(ls -A "$R/tmp" | head -1))"
    exit 1
  fi
  extra="$(cd "$R" && ls -A | grep -vxE 'bin|tmp|nightly_export\.sh|export\.csv|export\.lock|\.fetch\.pid|\.out|\.err')"
  if [ -n "$extra" ]; then
    echo "❌ $1, a stray file was left in the job directory: $(printf '%s\n' "$extra" | head -1)"
    exit 1
  fi
}

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"

# 1. normal run
fresh normal
(cd "$R" && $LIMIT env FETCH_ROWS=6 TMPDIR="$R/tmp" bash ./nightly_export.sh </dev/null >"$R/.out" 2>"$R/.err")
code=$?
want="$(cd "$R" && FETCH_ROWS=6 bin/fetch_orders | bin/to_csv)"
if [ "$code" != 0 ]; then
  echo "❌ a normal run exited with status $code: $(head -1 "$R/.err")"
  exit 1
fi
if [ "$(cat "$R/export.csv")" != "$want" ]; then
  echo "❌ after a normal run, export.csv does not hold the converted orders"
  exit 1
fi
leftovers "after a normal run"

# 2. the converter fails halfway
fresh tocsv
(cd "$R" && $LIMIT env FETCH_ROWS=6 TO_CSV_FAIL_AT=3 TMPDIR="$R/tmp" bash ./nightly_export.sh </dev/null >"$R/.out" 2>"$R/.err")
code=$?
if [ "$code" = 0 ]; then
  echo "❌ when to_csv fails, nightly_export.sh still exits 0"
  exit 1
fi
if [ "$(cat "$R/export.csv" 2>/dev/null)" != "$YESTERDAY" ]; then
  echo "❌ when to_csv fails, export.csv is replaced by a half-written file; keep yesterday's until the new one is complete"
  exit 1
fi
leftovers "when to_csv fails"

# 3. TERM while the slow fetch is running
fresh term
(cd "$R" && exec env FETCH_ROWS=300 TMPDIR="$R/tmp" bash ./nightly_export.sh </dev/null >"$R/.out" 2>"$R/.err") &
pid=$!
sleep 1
kill -TERM "$pid" 2>/dev/null
t=0
while kill -0 "$pid" 2>/dev/null && [ "$t" -lt 30 ]; do sleep 0.1; t=$((t + 1)); done
if kill -0 "$pid" 2>/dev/null; then
  kill -KILL "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  echo "❌ after SIGTERM, nightly_export.sh was still running 3 s later: bash runs a trap only when the foreground command has finished"
  exit 1
fi
wait "$pid"
code=$?
if [ "$code" != 143 ]; then
  echo "❌ after SIGTERM, nightly_export.sh exited with status $code, expected 143 (128 + 15)"
  exit 1
fi
sleep 0.3
if [ -f "$R/.fetch.pid" ] && kill -0 "$(cat "$R/.fetch.pid")" 2>/dev/null; then
  echo "❌ after SIGTERM, the script exited but fetch_orders is still running; stop it in the cleanup"
  exit 1
fi
if [ "$(cat "$R/export.csv" 2>/dev/null)" != "$YESTERDAY" ]; then
  echo "❌ after SIGTERM, export.csv is not yesterday's file any more"
  exit 1
fi
leftovers "after SIGTERM"

# 4. another export holds the lock
fresh locked
echo 4242 > "$R/export.lock"
(cd "$R" && $LIMIT env FETCH_ROWS=2 TMPDIR="$R/tmp" bash ./nightly_export.sh </dev/null >"$R/.out" 2>"$R/.err")
code=$?
if [ "$code" = 0 ]; then
  echo "❌ when export.lock already exists, nightly_export.sh must refuse to run (non-zero exit)"
  exit 1
fi
if [ "$(cat "$R/export.lock" 2>/dev/null)" != 4242 ]; then
  echo "❌ when export.lock already exists, the script removed or changed the OTHER run's lock; only clean up what this run created"
  exit 1
fi
leftovers "when export.lock already existed"

echo "✅ nightly_export.sh cleans up after success, failure and SIGTERM, and never leaves a half-written export.csv"
exit 0
