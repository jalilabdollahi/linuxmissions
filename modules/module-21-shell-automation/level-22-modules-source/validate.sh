#!/bin/bash
# 1. lib/common.sh as a library: sourcing prints nothing, keeps set -o/shopt
#    and the directory, does not exit, a second source is a no-op (guard),
#    and log/die/require_cmd behave as STYLE.txt says, also under set -u.
# 2. The three scripts have no own copies of the helpers and use the lib.
# 3. Each script runs from a scratch copy of the repo: by full path from /,
#    as scripts/NAME.sh from the repo, through bin/NAME, and through a second
#    symlink to bin/NAME in another directory. Stdout must stay empty and
#    stderr must be exactly the expected log/error line.
SANDBOX="$1"
S="$(cd "$SANDBOX" && pwd -P)"
LIB="$S/lib/common.sh"
NAMES="rotate_logs check_inbox sync_assets"

for n in $NAMES; do
  if [ ! -f "$S/scripts/$n.sh" ]; then
    echo "❌ scripts/$n.sh is missing (type reset to get it back)"
    exit 1
  fi
done
if [ ! -f "$LIB" ]; then
  echo "❌ lib/common.sh does not exist yet"
  exit 1
fi

WORK="$(mktemp -d "$S/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# lib CODE: run CODE in a clean bash with $0 = myprog
lib() {
  (cd "$WORK" && $LIMIT env -i PATH="$PATH" HOME="$WORK" bash --noprofile --norc -c "$1" myprog \
     </dev/null >"$WORK/out" 2>"$WORK/err")
  CODE=$?
}

# --- 1. the library ---
lib "before=\$(set +o; shopt -p); here=\$PWD; source '$LIB'; echo \"STATUS=\$?\"; after=\$(set +o; shopt -p);
     [ \"\$before\" = \"\$after\" ] && echo SAMEOPTS; [ \"\$PWD\" = \"\$here\" ] && echo SAMEDIR; echo ALIVE"
if ! grep -q '^ALIVE$' "$WORK/out"; then
  echo "❌ sourcing lib/common.sh ends the shell that sources it (an exit in the library?)"
  exit 1
fi
if [ -n "$(grep -vE '^(STATUS=.*|SAMEOPTS|SAMEDIR|ALIVE)$' "$WORK/out")" ] || [ -s "$WORK/err" ]; then
  echo "❌ sourcing lib/common.sh prints something; a library should only define functions"
  exit 1
fi
if ! grep -q '^STATUS=0$' "$WORK/out"; then
  echo "❌ source lib/common.sh returns a non-zero status"
  exit 1
fi
if ! grep -q '^SAMEOPTS$' "$WORK/out"; then
  echo "❌ sourcing lib/common.sh changes shell options (set -e, -u, pipefail, shopt...); leave that to the scripts"
  exit 1
fi
if ! grep -q '^SAMEDIR$' "$WORK/out"; then
  echo "❌ sourcing lib/common.sh changes the current directory"
  exit 1
fi

lib "source '$LIB'; log() { echo REDEFINED; }; source '$LIB'; log x"
if [ "$(cat "$WORK/out")" != "REDEFINED" ]; then
  echo "❌ sourcing lib/common.sh a second time defines everything again; add an include guard so it loads once"
  exit 1
fi

lib "set -u; source '$LIB'; log disk is fine; log 'two  spaces'"
if [ "$CODE" != 0 ] || [ -s "$WORK/out" ] || [ "$(cat "$WORK/err")" != "myprog: disk is fine
myprog: two  spaces" ]; then
  echo "❌ log should print '<prog>: MESSAGE' on stderr only (also under set -u); got: $(head -1 "$WORK/err")$(head -1 "$WORK/out")"
  exit 1
fi

lib "set -eu; source '$LIB'; die 'quota exceeded'; echo AFTER"
if [ "$CODE" != 1 ] || grep -q AFTER "$WORK/out" || [ "$(cat "$WORK/err")" != "myprog: error: quota exceeded" ]; then
  echo "❌ die should print '<prog>: error: MESSAGE' on stderr and exit with status 1 (got status $CODE: $(head -1 "$WORK/err"))"
  exit 1
fi

lib "set -eu; source '$LIB'; require_cmd ls sh; echo FOUND"
if [ "$(cat "$WORK/out")" != FOUND ] || [ -s "$WORK/err" ]; then
  echo "❌ require_cmd ls sh should succeed silently when the commands exist"
  exit 1
fi
lib "set -eu; source '$LIB'; require_cmd ls no-such-tool-x9 sh; echo AFTER"
if [ "$CODE" != 1 ] || grep -q AFTER "$WORK/out" || [ "$(cat "$WORK/err")" != "myprog: error: missing command: no-such-tool-x9" ]; then
  echo "❌ require_cmd with a missing command should die with 'missing command: NAME' (status 1); got status $CODE: $(head -1 "$WORK/err")"
  exit 1
fi

# --- 2. no copies left in the scripts ---
for n in $NAMES; do
  code_only="$(sed 's/#.*//' "$S/scripts/$n.sh")"
  if printf '%s\n' "$code_only" | grep -Eq '(^|[;{[:space:]])(function[[:space:]]+)?(log|die|require_cmd)[[:space:]]*\([[:space:]]*\)|function[[:space:]]+(log|die|require_cmd)([[:space:]]|$)'; then
    echo "❌ scripts/$n.sh still defines its own log/die/require_cmd; use the ones from lib/common.sh"
    exit 1
  fi
  if ! printf '%s\n' "$code_only" | grep -q 'common\.sh'; then
    echo "❌ scripts/$n.sh does not load lib/common.sh"
    exit 1
  fi
done

# --- 3. run the scripts in a scratch copy of the repo, four ways ---
W="$WORK/repo"
mkdir -p "$W/scripts" "$W/lib" "$W/bin" "$WORK/admin-bin" "$WORK/elsewhere"
cp "$S"/scripts/*.sh "$W/scripts/"
cp -R "$S/lib/." "$W/lib/"
chmod +x "$W"/scripts/*.sh
for pair in rotate_logs:rotate-logs check_inbox:check-inbox sync_assets:sync-assets; do
  ln -s "../scripts/${pair%%:*}.sh" "$W/bin/${pair#*:}"
  ln -s "$W/bin/${pair#*:}" "$WORK/admin-bin/${pair#*:}"
done

# way N SCRIPT CMDNAME: sets DIR (where to run), CMD (what to run) and PROG
way() {
  case $1 in
    1) DIR=/;                 CMD="$W/scripts/$2.sh";  PROG="$2.sh";  HOW="by full path from /" ;;
    2) DIR="$W";              CMD="scripts/$2.sh";     PROG="$2.sh";  HOW="as scripts/$2.sh from the repo" ;;
    3) DIR="$WORK/elsewhere"; CMD="$W/bin/$3";         PROG="$3";     HOW="through bin/$3" ;;
    4) DIR="$WORK/elsewhere"; CMD="$WORK/admin-bin/$3"; PROG="$3";    HOW="through a symlink to bin/$3 in another directory" ;;
  esac
}
# go WANT_STATUS WANT_STDERR ARGS...
go() {
  local want_code="$1" want_err="$2"; shift 2
  (cd "$DIR" && $LIMIT "$CMD" "$@" </dev/null >"$WORK/out" 2>"$WORK/err")
  local code=$?
  if grep -q 'common.sh' "$WORK/err"; then
    echo "❌ started $HOW, the script cannot find lib/common.sh: $(head -1 "$WORK/err")"
    exit 1
  fi
  if [ "$code" != "$want_code" ] || [ "$(cat "$WORK/err")" != "$want_err" ] || [ -s "$WORK/out" ]; then
    echo "❌ started $HOW with '$*': expected status $want_code and only '$want_err' on stderr; got status $code, stderr '$(head -1 "$WORK/err")'$( [ -s "$WORK/out" ] && echo ", stdout '$(head -1 "$WORK/out")'")"
    exit 1
  fi
}

for w in 1 2 3 4; do
  D="$WORK/data$w"
  rm -rf "$D"; mkdir -p "$D/logs" "$D/inbox" "$D/src/img" "$D/dst"
  echo "line $w" > "$D/logs/app.log"
  echo "other $w" > "$D/logs/the worker.log"
  echo "not a log" > "$D/logs/notes.txt"
  for i in 1 2 3 4; do echo "$i" > "$D/inbox/msg$i.eml"; done
  echo "css" > "$D/src/site.css"; echo "png" > "$D/src/img/logo.png"; echo "js" > "$D/src/app.js"

  way "$w" rotate_logs rotate-logs
  go 0 "$PROG: rotated 2 file(s) in $D/logs" "$D/logs"
  if [ "$(gzip -dc "$D/logs/the worker.log.1.gz" 2>/dev/null)" != "other $w" ] || [ -s "$D/logs/app.log" ]; then
    echo "❌ started $HOW, rotate_logs.sh did not rotate the logs"
    exit 1
  fi
  go 1 "$PROG: error: no such directory: $D/nope" "$D/nope"

  way "$w" check_inbox check-inbox
  go 0 "$PROG: $D/inbox: 4 file(s), ok" "$D/inbox" 10
  go 1 "$PROG: error: $D/inbox has 4 files (max 3)" "$D/inbox" 3

  way "$w" sync_assets sync-assets
  go 0 "$PROG: synced 3 file(s) to $D/dst" "$D/src" "$D/dst"
  if [ "$(cat "$D/dst/img/logo.png" 2>/dev/null)" != png ]; then
    echo "❌ started $HOW, sync_assets.sh did not copy the files"
    exit 1
  fi
  go 1 "$PROG: error: usage: sync-assets SRC DEST" "$D/src"
done

echo "✅ one lib/common.sh, safe to source, used by all three scripts however they are started"
exit 0
