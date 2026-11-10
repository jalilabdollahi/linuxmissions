#!/bin/bash
# Missing Warnings: build.sh prints its compiler warnings on stderr and its lint
# and test warnings on stdout, and exits with the number of failed test suites.
# A plain `./build.sh | grep -c WARN` misses the stderr half, and `$?` after the
# pipeline is grep's status. Every run is recorded (encoded) in .build/history,
# because the flaky test phase makes each run a little different.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .build src
touch .build/history

for f in ledger invoice export net main; do
  printf '/* %s.c - billing-svc */\nint %s_init(void) { return 0; }\n' "$f" "$f" > "src/$f.c"
done

cc_pool=(
  "src/ledger.c:%d: WARN implicit conversion from 'long' to 'int' may lose precision"
  "src/ledger.c:%d: WARN unused variable 'tmp_total'"
  "src/invoice.c:%d: WARN comparison of integers of different signs"
  "src/invoice.c:%d: WARN 'strncpy' output may be truncated copying 32 bytes"
  "src/export.c:%d: WARN 'csv_escape' is deprecated, use 'csv_quote'"
  "src/net.c:%d: WARN unused parameter 'flags'"
  "src/net.c:%d: WARN variable 'retries' set but not used"
  "src/main.c:%d: WARN no previous prototype for 'init_metrics'"
  "src/main.c:%d: WARN control reaches end of non-void function"
)
lint_pool=(
  "lint: WARN config key 'retry_ms' is deprecated (config/billing.yaml:14)"
  "lint: WARN TODO older than 180 days in src/invoice.c"
  "lint: WARN shell script scripts/rotate.sh has no 'set -u'"
  "lint: WARN duplicated SQL literal in src/ledger.c and src/export.c"
  "lint: WARN docs/API.md links to a missing anchor #refunds"
  "lint: WARN Dockerfile uses 'latest' tag for base image"
)

# How many warnings of each kind, and which ones, differs per setup.
n_cc=$(( 5 + RANDOM % 4 ))
start=$(( RANDOM % ${#cc_pool[@]} ))
cc_lines=()
for i in $(seq 0 $(( n_cc - 1 ))); do
  cc_lines+=( "$(printf "${cc_pool[$(( (start + i) % ${#cc_pool[@]} ))]}" $(( 20 + RANDOM % 400 )))" )
done
n_lint=$(( 3 + RANDOM % 3 ))
start=$(( RANDOM % ${#lint_pool[@]} ))

{
  cat <<'HEAD'
#!/bin/bash
# build.sh - compile, lint and test billing-svc.
# Compiler diagnostics go to stderr (like gcc does); everything else goes to stdout.
# Exit status: 0 when every test suite passed, otherwise the number of failed suites.
cd "$(dirname "$0")" || exit 99
build_id=$(printf '%04x%04x' $RANDOM $RANDOM)
n_stderr=0
n_stdout=0
cc_warn()   { echo "$1" >&2; n_stderr=$(( n_stderr + 1 )); }
note_warn() { echo "$1";     n_stdout=$(( n_stdout + 1 )); }

echo "== build $build_id: compiling billing-svc"
HEAD
  for f in ledger invoice export net main; do
    echo "echo 'cc -O2 -Wall -c src/$f.c -o .build/$f.o'"
    for line in "${cc_lines[@]}"; do
      case "$line" in
        "src/$f.c:"*) printf 'cc_warn "%s"\n' "$line" ;;
      esac
    done
  done
  echo "echo 'cc -o .build/billing-svc .build/*.o'"
  echo "echo '== lint'"
  for i in $(seq 0 $(( n_lint - 1 ))); do
    printf 'note_warn "%s"\n' "${lint_pool[$(( (start + i) % ${#lint_pool[@]} ))]}"
  done
  cat <<'TAIL'
echo "lint: 212 files checked"

echo "== tests"
failed=0
for suite in unit-ledger unit-invoice api export integration; do
  if [ $(( RANDOM % 3 )) -eq 0 ]; then
    note_warn "WARN $suite: slow test retried ($(( 2 + RANDOM % 9 ))s, flaky)"
  fi
  case "$suite" in
    integration)
      echo "FAIL $suite: cannot connect to db.local:5432"
      failed=$(( failed + 1 )) ;;
    api|export)
      if [ $(( RANDOM % 3 )) -eq 0 ]; then
        echo "FAIL $suite: $(( 1 + RANDOM % 3 )) assertion(s) failed"
        failed=$(( failed + 1 ))
      else
        echo "ok   $suite"
      fi ;;
    *)
      echo "ok   $suite" ;;
  esac
done
echo "== build $build_id finished"

# Build bookkeeping for the CI dashboard (encoded, do not edit).
key=$(( 4096 + RANDOM ))
printf '%s %x %x %x %x\n' "$build_id" "$key" $(( (n_stderr + n_stdout) ^ key )) \
  $(( n_stdout ^ key )) $(( failed ^ key )) >> .build/history
exit "$failed"
TAIL
} > build.sh
chmod +x build.sh

cat > RELEASE-NOTES.txt <<'EOF'
Release checklist, billing-svc
------------------------------
The CI step `./build.sh | grep -c WARN` reports fewer warnings than anyone
can see scrolling past in the terminal, and the release dashboard always
shows the build as "passed" (status 0).

For the go/no-go meeting I need, from ONE run of ./build.sh:
  warn_count.txt    the number of lines containing WARN that the build printed
  build_status.txt  the exit status of build.sh itself
A rerun is not the same: the test phase is flaky.
EOF
