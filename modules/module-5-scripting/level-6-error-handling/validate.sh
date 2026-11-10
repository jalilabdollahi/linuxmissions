#!/bin/bash
# Checks that safe_copy.sh turns on strict mode, then runs it in a scratch
# directory with no argument, a missing file, an unreadable file and a good
# file whose name has spaces.
SANDBOX="$1"
SCRIPT="$SANDBOX/safe_copy.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ safe_copy.sh is missing (type reset to get it back)"
  exit 1
fi

# --- the construct: set -e, set -u and pipefail must all be switched on ---
setlines="$(sed 's/#.*//' "$SCRIPT" | grep -E '^[[:space:]]*set[[:space:]]')"
has() { printf '%s\n' "$setlines" | grep -Eq -- "$1"; }
if ! has '[[:space:]]-[a-zA-Z]*e' && ! has '-[a-zA-Z]*o[[:space:]]+errexit'; then
  echo "❌ safe_copy.sh does not turn on 'set -e' (exit on the first failing command)"
  exit 1
fi
if ! has '[[:space:]]-[a-zA-Z]*u' && ! has '-[a-zA-Z]*o[[:space:]]+nounset'; then
  echo "❌ safe_copy.sh does not turn on 'set -u' (unset variables are errors)"
  exit 1
fi
if ! has '-[a-zA-Z]*o[[:space:]]+pipefail'; then
  echo "❌ safe_copy.sh does not turn on 'set -o pipefail' (a pipeline fails if any part fails)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/safe_copy.sh"
mkdir -p "$WORK/deploy"
printf '%s\n' '# cache settings' 'size=512M' '# ttl in seconds' 'ttl=600' 'path=/var/cache/shop' > "$WORK/cache settings.conf"
printf '%s\n' '# secret' 'token=abc' > "$WORK/locked.conf"
chmod 000 "$WORK/locked.conf"

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# run ARGS... : sets OUT, ERR, CODE
run() {
  (cd "$WORK" && $LIMIT bash ./safe_copy.sh "$@" </dev/null >"$WORK/.out" 2>"$WORK/.err")
  CODE=$?
  OUT="$(tr -d '\r' < "$WORK/.out")"
  ERR="$(tr -d '\r' < "$WORK/.err")"
}

# 1. no argument
run
if [ "$CODE" != "1" ]; then
  echo "❌ with no argument, safe_copy.sh exited with status $CODE, expected 1"
  exit 1
fi
if ! printf '%s\n' "$ERR" | grep -qx 'SOURCE_FILE is required'; then
  if printf '%s\n' "$OUT" | grep -qx 'SOURCE_FILE is required'; then
    echo "❌ 'SOURCE_FILE is required' went to stdout; error messages belong on stderr (>&2)"
  else
    echo "❌ with no argument, safe_copy.sh should print 'SOURCE_FILE is required' on stderr"
  fi
  exit 1
fi
if printf '%s' "$OUT" | grep -q 'copy complete'; then
  echo "❌ with no argument, safe_copy.sh still printed 'copy complete'"
  exit 1
fi

# 2. missing file
run "no such file.conf"
if [ "$CODE" = "0" ] || printf '%s' "$OUT" | grep -q 'copy complete'; then
  echo "❌ with a source file that does not exist, safe_copy.sh still reports success (status $CODE)"
  exit 1
fi

# 3. unreadable file (only meaningful when not running as root)
if [ "$(id -u)" != "0" ]; then
  run "locked.conf"
  if [ "$CODE" = "0" ] || printf '%s' "$OUT" | grep -q 'copy complete'; then
    echo "❌ with a source file that exists but cannot be read, safe_copy.sh still reports success (status $CODE)"
    exit 1
  fi
fi

# 4. good file with spaces in its name
rm -f "$WORK/deploy/app.conf"
run "cache settings.conf"
if [ "$CODE" != "0" ]; then
  echo "❌ bash safe_copy.sh \"cache settings.conf\" failed (status $CODE): $(printf '%s' "$ERR" | head -1)"
  exit 1
fi
if ! printf '%s\n' "$OUT" | grep -qx 'copy complete'; then
  echo "❌ a successful copy should still print 'copy complete'"
  exit 1
fi
if [ "$(cat "$WORK/deploy/app.conf" 2>/dev/null)" != "$(printf '%s\n' 'size=512M' 'ttl=600' 'path=/var/cache/shop')" ]; then
  echo "❌ deploy/app.conf is not the source file minus its comment lines"
  exit 1
fi

echo "✅ safe_copy.sh fails loudly on bad input and still copies good configs"
exit 0
