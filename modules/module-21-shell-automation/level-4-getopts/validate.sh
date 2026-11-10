#!/bin/bash
# Runs rotate.sh with about ten command lines on fresh fixture directories and
# compares the config line it prints, the exit status, stdout/stderr use and
# (for two runs) which files are left after the rotation.
SANDBOX="$1"
SCRIPT="$SANDBOX/rotate.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ rotate.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/rotate.sh"
cd "$WORK" || exit 1
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

fixture() {
  rm -rf logs "my logs"
  mkdir logs "my logs"
  for i in 1 2 3 4 5; do
    touch -t "20261101000$i" "logs/app-$i.log" "my logs/app-$i.log"
  done
  for i in 1 2 3; do
    touch -t "20261102000$i" "my logs/worker $i.log"
  done
  touch "logs/notes.txt" "my logs/notes.txt"
}
left() { (cd "$1" && ls -1 | tr '\n' ',' ); }

# expect_ok "ARGS (for messages)" "CONFIG LINE" ARG...
expect_ok() {
  shown=$1 want=$2; shift 2
  fixture
  $LIMIT bash ./rotate.sh "$@" </dev/null >out 2>err
  code=$?
  if [ "$code" != 0 ]; then
    echo "❌ ./rotate.sh $shown exited with $code ($(head -n 1 err)), expected 0"
    exit 1
  fi
  if [ "$(head -n 1 out)" != "$want" ]; then
    echo "❌ ./rotate.sh $shown printed '$(head -n 1 out)', expected '$want'"
    exit 1
  fi
}

# expect_usage "ARGS (for messages)" ARG...
expect_usage() {
  shown=$1; shift
  fixture
  before=$(left logs)
  $LIMIT bash ./rotate.sh "$@" </dev/null >out 2>err
  code=$?
  if [ "$code" != 2 ]; then
    echo "❌ ./rotate.sh $shown is wrong usage and must exit 2, but exited with $code"
    exit 1
  fi
  if [ -s out ] || [ ! -s err ]; then
    echo "❌ ./rotate.sh $shown: the usage message belongs on stderr, and nothing on stdout"
    exit 1
  fi
  if [ "$(left logs)" != "$before" ]; then
    echo "❌ ./rotate.sh $shown deleted files although the command line was wrong"
    exit 1
  fi
}

expect_ok "-v -n 3 -d logs" "rotate: dir=logs keep=3 verbose=1 patterns=[*.log]" -v -n 3 -d logs
if [ "$(left logs)" != "app-3.log,app-4.log,app-5.log,notes.txt," ]; then
  echo "❌ ./rotate.sh -v -n 3 -d logs left these files: $(left logs) (expected the 3 newest app logs and notes.txt)"
  exit 1
fi
if ! grep -q 'removed' err; then
  echo "❌ ./rotate.sh -v -n 3 -d logs did not report the removed files on stderr"
  exit 1
fi
expect_ok "-vn3 -d logs" "rotate: dir=logs keep=3 verbose=1 patterns=[*.log]" -vn3 -d logs
expect_ok "-n2 -v -dlogs" "rotate: dir=logs keep=2 verbose=1 patterns=[*.log]" -n2 -v -dlogs
expect_ok "-d logs" "rotate: dir=logs keep=7 verbose=0 patterns=[*.log]" -d logs
expect_ok "-d 'my logs' -n 2 'app-*.log' 'worker *.log'" \
  "rotate: dir=my logs keep=2 verbose=0 patterns=[app-*.log][worker *.log]" -d "my logs" -n 2 'app-*.log' 'worker *.log'
if [ "$(left "my logs")" != "app-4.log,app-5.log,notes.txt,worker 2.log,worker 3.log," ]; then
  echo "❌ ./rotate.sh -d 'my logs' -n 2 'app-*.log' 'worker *.log' left: $(left "my logs")"
  exit 1
fi
expect_ok "-d logs -- -odd-name" "rotate: dir=logs keep=7 verbose=0 patterns=[-odd-name]" -d logs -- -odd-name
expect_ok "-n 4 -d logs -v" "rotate: dir=logs keep=4 verbose=1 patterns=[*.log]" -n 4 -d logs -v

expect_usage "-n 3 (no -d)" -n 3
expect_usage "-v" -v
expect_usage "-x -d logs" -x -d logs
expect_usage "-d logs -n" -d logs -n
expect_usage "-d" -d

echo "✅ rotate.sh parses its options like any standard tool: defaults, clusters, attached values, -- and usage errors"
exit 0
