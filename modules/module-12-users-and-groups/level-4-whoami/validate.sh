#!/bin/bash
# Run a copy of deploy.sh in a scratch dir with its own deploy.allowed:
#  1. allowed = someone else, USER/LOGNAME faked to that name -> exit 1, no deploy
#  2. allowed = the real caller, USER/LOGNAME = someone else  -> deploys
#  3. allowed = the real caller, USER/LOGNAME unset            -> deploys
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f deploy.sh ]; then
  echo "❌ deploy.sh is gone; type 'reset' to get it back"
  exit 1
fi
if [ ! -x deploy.sh ]; then
  echo "❌ deploy.sh is no longer executable (chmod +x deploy.sh)"
  exit 1
fi
if [ ! -s build/VERSION ] || ! ls build/*.tar.gz >/dev/null 2>&1; then
  echo "❌ build/ is incomplete; type 'reset' to get it back"
  exit 1
fi
me=$(id -un)
ver=$(cat build/VERSION)
other=release
[ "$me" = release ] && other=deploybot

T=$(mktemp -d "${TMPDIR:-/tmp}/lm-whoami.XXXXXX")
trap 'rm -rf "$T"' EXIT
fresh() {
  rm -rf "$T/run"; mkdir -p "$T/run"
  cp -p deploy.sh "$T/run/" && cp -Rp build "$T/run/"
  printf '%s\n' "$1" > "$T/run/deploy.allowed"
}
deployed() { ls "$T/run/staging/"*.tar.gz >/dev/null 2>&1 && grep -qF "deployed $ver" "$T/run/deploy.log" 2>/dev/null; }

# 1. a faked USER must not get through
fresh "$other"
(cd "$T/run" && USER=$other LOGNAME=$other ./deploy.sh </dev/null >/dev/null 2>&1); rc=$?
if [ $rc -eq 0 ] || deployed; then
  echo "❌ USER=$other ./deploy.sh still deploys although you are $me: the guard trusts a variable the caller sets"
  exit 1
fi
if [ $rc -ne 1 ]; then
  echo "❌ when it refuses, deploy.sh should exit with status 1 (it exited with $rc)"
  exit 1
fi

# 2. the real allowed account with a misleading USER must get through
fresh "$me"
out=$(cd "$T/run" && USER=$other LOGNAME=$other ./deploy.sh </dev/null 2>&1); rc=$?
if [ $rc -ne 0 ] || ! deployed; then
  echo "❌ with deploy.allowed set to $me and USER=$other, deploy.sh refused to run for $me: it must check who you really are, not \$USER (and \$EUID is a number, not a name)"
  exit 1
fi

# 3. no USER or LOGNAME at all (cron, systemd, env -i)
fresh "$me"
(cd "$T/run" && env -u USER -u LOGNAME ./deploy.sh </dev/null >/dev/null 2>&1); rc=$?
if [ $rc -ne 0 ] || ! deployed; then
  echo "❌ with USER and LOGNAME unset (as under cron), deploy.sh refuses $me; logname also fails without a terminal"
  exit 1
fi

echo "✅ deploy.sh now checks the effective user: faking USER no longer works, and $me can deploy with or without USER set"
exit 0
