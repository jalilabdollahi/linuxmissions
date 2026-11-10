#!/bin/bash
# Runs run_all.sh in a scratch folder with probe tasks. Each probe marks when it
# starts, sleeps 1s, then records how many probes had started by then:
# 3 everywhere means they overlapped (parallel). The probe results must exist
# when run_all.sh returns (it waited), and the exit status must reflect failures.
# A failing probe fails immediately, so a script that bails out on the first
# failure is caught returning while the other two are still running.
SANDBOX="$1"
SCRIPT="$SANDBOX/run_all.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ run_all.sh is missing (type reset to get it back)"
  exit 1
fi
if ! grep -v '^[[:space:]]*#' "$SCRIPT" | grep -q 'task-'; then
  echo "❌ run_all.sh does not start the tasks yet"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"

# trial FAILING_TASK  (empty = all succeed); sets CODE
trial() {
  rm -rf "$WORK/run"
  mkdir -p "$WORK/run"
  cp "$SCRIPT" "$WORK/run/run_all.sh"
  for t in a b c; do
    if [ "$t" = "$1" ]; then
      printf '#!/bin/bash\ntouch started.%s seen.%s\nexit 3\n' "$t" "$t" > "$WORK/run/task-$t.sh"
    else
      printf '#!/bin/bash\ntouch started.%s\nsleep 1\nls started.* | wc -l | tr -d " " > seen.%s\n' "$t" "$t" > "$WORK/run/task-$t.sh"
    fi
    chmod +x "$WORK/run/task-$t.sh"
  done
  (cd "$WORK/run" && $LIMIT bash ./run_all.sh </dev/null >/dev/null 2>&1)
  CODE=$?
}

trial ""
for t in a b c; do
  if [ ! -e "$WORK/run/seen.$t" ]; then
    sleep 2   # let stray background tasks show whether they were started at all
    if [ -e "$WORK/run/started.$t" ]; then
      echo "❌ run_all.sh returned before task-$t.sh had finished; it has to wait for all of them"
    else
      echo "❌ run_all.sh never started task-$t.sh"
    fi
    exit 1
  fi
done
for t in a b c; do
  if [ "$(cat "$WORK/run/seen.$t")" != "3" ]; then
    echo "❌ the tasks ran one after another, not at the same time"
    exit 1
  fi
done
if [ "$CODE" != "0" ]; then
  echo "❌ all three tasks succeeded, but run_all.sh exited with status $CODE (expected 0)"
  exit 1
fi

trial a
if [ "$CODE" = "0" ]; then
  echo "❌ task-a.sh failed (exit 3) but run_all.sh exited with status 0; check the exit status of every task"
  exit 1
fi
for t in b c; do
  if [ ! -e "$WORK/run/seen.$t" ]; then
    echo "❌ after task-a.sh failed, run_all.sh returned while task-$t.sh was still running"
    exit 1
  fi
done

trial c
if [ "$CODE" = "0" ]; then
  echo "❌ task-c.sh failed (exit 3) but run_all.sh exited with status 0"
  exit 1
fi

echo "✅ run_all.sh runs the tasks in parallel, waits for all of them and reports failures"
exit 0
