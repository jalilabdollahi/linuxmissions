#!/bin/bash
# Runs run_checks.sh in two scratch folders with fixture checks, a mock
# `sleep` on PATH that only records the requested delays, CHECK_TIMEOUT=1:
#   set 1: pass, fail, pass on the 2nd try, hang, a README, a helper folder;
#          a second run started 0.5 s later must exit 75 while the first runs
#   set 2: pass, pass on the 3rd try, fail, a non-executable script, a name
#          with spaces; RETRY_DELAY=3
# Compares summary.txt, the exit status, which checks ran how often, and the
# backoff delays.
SANDBOX="$1"
SCRIPT="$SANDBOX/run_checks.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ run_checks.sh is missing (type reset to get it back)"
  exit 1
fi

if ! sed 's/#.*//' "$SCRIPT" | grep -q 'timeout'; then
  echo "❌ run_checks.sh does not limit how long a check may run yet (a check can hang forever)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'pkill -f "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
REAL_SLEEP="$(command -v sleep)"
mkdir -p "$WORK/mockbin"
cat > "$WORK/mockbin/sleep" <<'MOCK'
#!/bin/bash
echo "${1%s}" >> "$SLEEP_LOG"
MOCK
chmod +x "$WORK/mockbin/sleep"

# check DIR NAME BODY: an executable fixture that records each call
check() {
  printf '#!/bin/bash\necho "%s" >> "%s/calls"\n%s\n' "$2" "$1" "$3" > "$1/checks.d/$2"
  chmod +x "$1/checks.d/$2"
}
# setup_dir DIR
setup_dir() {
  mkdir -p "$1/checks.d"
  cp "$SCRIPT" "$1/run_checks.sh"
  : > "$1/calls"; : > "$1/sleeps"
}
# start DIR [VAR=value...]: run in the background; PID in $PID
start() {
  local d="$1"; shift
  (cd "$d" && exec env PATH="$WORK/mockbin:$PATH" SLEEP_LOG="$d/sleeps" CHECK_TIMEOUT=1 "$@" \
     bash ./run_checks.sh </dev/null >"$d/.out" 2>"$d/.err") &
  PID=$!
}
# finish PID LIMIT: wait up to LIMIT seconds; CODE, or exit with a message
finish() {
  local t=0
  while kill -0 "$1" 2>/dev/null && [ "$t" -lt $(( $2 * 10 )) ]; do "$REAL_SLEEP" 0.1; t=$((t + 1)); done
  if kill -0 "$1" 2>/dev/null; then
    kill -9 "$1" 2>/dev/null
    wait "$1" 2>/dev/null
    echo "❌ run_checks.sh was still running after $2 s: the hanging check must be stopped by a timeout (CHECK_TIMEOUT=1)"
    exit 1
  fi
  wait "$1"
  CODE=$?
}
# compare DIR WANT_SUMMARY WANT_CODE WANT_CALLS WANT_SLEEPS LABEL
compare() {
  if [ ! -f "$1/summary.txt" ]; then
    echo "❌ $6: no summary.txt was written ($(head -1 "$1/.err"))"
    exit 1
  fi
  if [ "$(cat "$1/summary.txt")" != "$2" ]; then
    bad="$(diff <(printf '%s\n' "$2") "$1/summary.txt" | grep '^[<>]' | head -2 | tr '\n' ' ')"
    echo "❌ $6: summary.txt is not as expected (diff: $bad)"
    exit 1
  fi
  if [ "$CODE" != "$3" ]; then
    echo "❌ $6: exit status $CODE, expected $3 (the number of checks that did not pass)"
    exit 1
  fi
  calls="$(LC_ALL=C sort "$1/calls" | uniq -c | awk '{ c = $1; $1 = ""; sub(/^ /, ""); printf "%s=%s ", $0, c }')"
  if [ "$calls" != "$4" ]; then
    echo "❌ $6: the checks were not run the right number of times: got $calls, expected $4"
    exit 1
  fi
  sleeps="$(tr '\n' ' ' < "$1/sleeps" | sed 's/ $//')"
  if [ "$sleeps" != "$5" ]; then
    echo "❌ $6: the delays before retries were '$sleeps', expected '$5' (RETRY_DELAY before the 2nd attempt, twice that before the 3rd)"
    exit 1
  fi
}

# ---- set 1 ----
A="$WORK/set1"
setup_dir "$A"
mkdir -p "$A/checks.d/helpers"
printf '#!/bin/bash\necho helper >> "%s/calls"\n' "$A" > "$A/checks.d/helpers/run.sh"
chmod +x "$A/checks.d/helpers/run.sh"
echo "not a check" > "$A/checks.d/README"
check "$A" 10-disk 'exit 0'
check "$A" 20-queue 'echo "queue too deep" >&2; exit 3'
check "$A" 30-api "n=\$(cat '$A/api' 2>/dev/null || echo 0); echo \$((n + 1)) > '$A/api'; [ \"\$n\" -ge 1 ]"
check "$A" 40-nfs "exec -a \"$A/hang\" $REAL_SLEEP 30"

start "$A" RETRY_DELAY=1
first=$PID
"$REAL_SLEEP" 0.5
(cd "$A" && exec env PATH="$WORK/mockbin:$PATH" SLEEP_LOG="$A/sleeps.second" CHECK_TIMEOUT=1 RETRY_DELAY=1 \
   bash ./run_checks.sh </dev/null >"$A/.out2" 2>"$A/.err2") &
second=$!
t=0
while kill -0 "$second" 2>/dev/null && [ "$t" -lt 30 ]; do "$REAL_SLEEP" 0.1; t=$((t + 1)); done
if kill -0 "$second" 2>/dev/null; then
  kill -9 "$second" 2>/dev/null
  wait "$second" 2>/dev/null
  finish "$first" 8
  echo "❌ a second run started while the first was running did not exit at once; it must not wait for the lock"
  exit 1
fi
wait "$second"
code2=$?
if [ "$code2" != 75 ]; then
  finish "$first" 8
  echo "❌ a second run started while the first was running exited with status $code2, expected 75"
  exit 1
fi
if ! kill -0 "$first" 2>/dev/null; then
  echo "❌ the first run had already finished when the second one started (it should still be busy with the hanging check)"
  exit 1
fi
finish "$first" 8
compare "$A" "10-disk PASS 1
20-queue FAIL 3
30-api PASS 2
40-nfs TIMEOUT 3
failed 2 of 4" 2 "10-disk=1 20-queue=3 30-api=2 40-nfs=3 " "1 2 1 1 2" "with checks pass/fail/flaky/hanging"

# ---- set 2 ----
B="$WORK/set2"
setup_dir "$B"
check "$B" a-ok 'exit 0'
check "$B" b-third "n=\$(cat '$B/third' 2>/dev/null || echo 0); echo \$((n + 1)) > '$B/third'; [ \"\$n\" -ge 2 ]"
check "$B" c-bad 'exit 1'
check "$B" "e smtp relay" 'exit 0'
printf '#!/bin/bash\necho "d disabled.sh" >> "%s/calls"\n' "$B" > "$B/checks.d/d disabled.sh"
start "$B" RETRY_DELAY=3
finish "$PID" 5
compare "$B" "a-ok PASS 1
b-third PASS 3
c-bad FAIL 3
e smtp relay PASS 1
failed 1 of 4" 1 "a-ok=1 b-third=3 c-bad=3 e smtp relay=1 " "3 6 3 6" "with a check that passes on the 3rd try, a disabled script and a name with spaces"

echo "✅ run_checks.sh times out, retries with backoff, skips non-checks, locks, and reports exactly"
exit 0
