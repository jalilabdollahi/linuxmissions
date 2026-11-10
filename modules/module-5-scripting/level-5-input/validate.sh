#!/bin/bash
# Sources load_env.sh in a fresh bash with app.env and with a second, unseen
# env file, then checks the exported environment (via `env`) line by line.
SANDBOX="$1"
SCRIPT="$SANDBOX/load_env.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ load_env.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/load_env.sh"

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# load FILE: source the loader in a clean bash; env -> $WORK/env.out, stderr -> $WORK/err.out
load() {
  (cd "$WORK" && $LIMIT env -i PATH="$PATH" HOME="$WORK" bash --noprofile --norc -c \
    'source ./load_env.sh "$1"; env' _ "$1" </dev/null >"$WORK/env.out" 2>"$WORK/err.out")
}

need() {  # need FILE-LABEL KEY=value
  if ! grep -qxF -- "$2" "$WORK/env.out"; then
    key="${2%%=*}"
    got="$(grep "^$key=" "$WORK/env.out" | head -1)"
    if [ -z "$got" ]; then
      echo "❌ after source load_env.sh $1, $key is not exported$3"
    else
      echo "❌ after source load_env.sh $1, got $got"
      echo "   expected $2"
    fi
    exit 1
  fi
}

# Test 1: the real app.env (fresh copy, so edits to the player's file don't matter)
printf '%s\n' \
  '# app.env - deploy settings, exported by load_env.sh' \
  '# Values are plain text from the settings form: never execute them.' \
  '' \
  'APP_NAME=linuxmissions' \
  'APP_ENV=staging' \
  'APP_PORT=8080' \
  'APP_TITLE=Linux Missions (staging)' \
  '' \
  '# database' \
  'DATABASE_URL=postgres://app:s3cret@db.internal:5432/missions?sslmode=require' \
  'MOTD=Deployed by $(whoami) on $(hostname)' > "$WORK/app.env"
printf '%s' 'LOG_LEVEL=info' >> "$WORK/app.env"

load app.env
if [ -s "$WORK/err.out" ]; then
  echo "❌ source load_env.sh app.env printed errors: $(head -1 "$WORK/err.out")"
  exit 1
fi
need app.env 'APP_NAME=linuxmissions'
need app.env 'APP_ENV=staging'
need app.env 'APP_PORT=8080'
need app.env 'APP_TITLE=Linux Missions (staging)'
need app.env 'DATABASE_URL=postgres://app:s3cret@db.internal:5432/missions?sslmode=require'
need app.env 'MOTD=Deployed by $(whoami) on $(hostname)'
need app.env 'LOG_LEVEL=info' " (it is the last line, and it has no newline at the end)"

# Test 2: a file the player has not seen
printf '%s\n' \
  '# worker settings' \
  'QUEUE_URL=amqp://guest:guest@mq.internal:5672/jobs?heartbeat=30' \
  '' \
  '#DISABLED_FEATURE=1' \
  'GREETING=  hello   world  ' \
  'PAYLOAD=$(touch hacked) `touch hacked2` ${HOME}' > "$WORK/worker.env"
printf '%s' 'WORKERS=12' >> "$WORK/worker.env"

load worker.env
if [ -e "$WORK/hacked" ] || [ -e "$WORK/hacked2" ]; then
  echo "❌ load_env.sh executed a \$(command) found in a value; values must stay plain text"
  exit 1
fi
if [ -s "$WORK/err.out" ]; then
  echo "❌ source load_env.sh on another env file printed errors: $(head -1 "$WORK/err.out")"
  exit 1
fi
need worker.env 'QUEUE_URL=amqp://guest:guest@mq.internal:5672/jobs?heartbeat=30'
need worker.env 'GREETING=  hello   world  '
need worker.env 'PAYLOAD=$(touch hacked) `touch hacked2` ${HOME}'
need worker.env 'WORKERS=12' " (it is the last line, and it has no newline at the end)"
if grep -q 'DISABLED_FEATURE' "$WORK/env.out"; then
  echo "❌ a commented-out line (#DISABLED_FEATURE=1) was exported"
  exit 1
fi

echo "✅ load_env.sh exports every setting literally and skips comments and blank lines"
exit 0
