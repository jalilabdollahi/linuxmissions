#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/.env" ]; then
  echo "❌ .env not found"
  exit 1
fi

# Do what start.sh does (source .env, then start a child process) in a clean
# environment, and capture what the child process really receives.
ERR="$(env -i PATH=/usr/bin:/bin HOME="$HOME" bash -c 'cd "$1" && . ./.env >/dev/null' _ "$SANDBOX" 2>&1 >/dev/null)"
if [ -n "$ERR" ]; then
  echo "❌ sourcing .env prints errors: $(printf '%s' "$ERR" | head -n 1)"
  exit 1
fi
CHILD_ENV="$(env -i PATH=/usr/bin:/bin HOME="$HOME" bash -c 'cd "$1" && . ./.env >/dev/null 2>&1 && exec env' _ "$SANDBOX")"

check() {
  local name="$1" want="$2" line
  line="$(printf '%s\n' "$CHILD_ENV" | grep "^$name=")"
  if [ -z "$line" ]; then
    if env -i PATH=/usr/bin:/bin bash -c 'cd "$1" && . ./.env >/dev/null 2>&1 && [ -n "${!2+x}" ]' _ "$SANDBOX" "$name"; then
      echo "❌ $name is set in the shell that sources .env, but not exported, so app.sh never sees it"
    else
      echo "❌ sourcing .env does not set $name"
    fi
    exit 1
  fi
  if [ "${line#*=}" != "$want" ]; then
    echo "❌ app.sh would receive $name='${line#*=}'"
    exit 1
  fi
}
check APP_MODE production
check APP_PORT 8080
check APP_NAME "My Shop"

echo "✅ .env is valid shell and exports all three settings to app.sh"
exit 0
