#!/bin/bash
# Install the LinuxMissions cron mocks into a level sandbox (see mocks/README.md).
#
#   install.sh SANDBOX [--bin DIR] [--spool DIR] [--user NAME] [--privileged]
#              [--now "YYYY-MM-DD HH:MM"] [TOOL...]
#
# TOOL: crontab (default), cron-run, cron-expand, run-parts, systemd-analyze.
# Copies the mock code to BIN/.mocks/cron/ and writes one small wrapper per
# tool to BIN (default SANDBOX/bin). The crontab wrapper sets LM_CRON_SPOOL
# (default SANDBOX/var/spool/cron/crontabs), LM_CRON_USER (default: the
# player's login name) and, if given, LM_CRON_PRIVILEGED / LM_CRON_NOW; each
# can still be overridden from the environment. cron-run gets --root SANDBOX
# unless the caller passes its own --root.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

SANDBOX="${1:?usage: install.sh SANDBOX [options] [TOOL...]}"
shift
SANDBOX="$(cd "$SANDBOX" && pwd)"
BIN="$SANDBOX/bin"
SPOOL="$SANDBOX/var/spool/cron/crontabs"
USER_NAME=""
PRIV=""
NOW=""
TOOLS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --bin) BIN="$2"; shift 2 ;;
    --spool) SPOOL="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --privileged) PRIV=1; shift ;;
    --now) NOW="$2"; shift 2 ;;
    crontab|cron-run|cron-expand|run-parts|systemd-analyze) TOOLS+=("$1"); shift ;;
    *) echo "install.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ ${#TOOLS[@]} -gt 0 ] || TOOLS=(crontab)
case "$BIN" in /*) ;; *) BIN="$SANDBOX/$BIN" ;; esac
case "$SPOOL" in /*) ;; *) SPOOL="$SANDBOX/$SPOOL" ;; esac

LIB="$BIN/.mocks/cron"
mkdir -p "$LIB" "$SPOOL"
cp "$HERE/cronlib.py" "$HERE/oncalendar.py" "$HERE/crontab" "$HERE/cron-run" \
   "$HERE/cron-expand" "$HERE/run-parts" "$HERE/systemd-analyze" "$LIB/"
chmod 755 "$LIB/crontab" "$LIB/cron-run" "$LIB/cron-expand" "$LIB/run-parts" "$LIB/systemd-analyze"

q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
# default VAR VALUE: a wrapper line that sets VAR unless the caller already did
default() { echo "[ -n \"\${$1+x}\" ] || $1=$(q "$2"); export $1"; }

for tool in "${TOOLS[@]}"; do
  {
    echo '#!/bin/sh'
    echo "# LinuxMissions mock $tool (mocks/cron, see mocks/README.md)."
    case "$tool" in
      crontab)
        default LM_CRON_SPOOL "$SPOOL"
        [ -z "$USER_NAME" ] || default LM_CRON_USER "$USER_NAME"
        [ -z "$PRIV" ] || default LM_CRON_PRIVILEGED 1
        [ -z "$NOW" ] || default LM_CRON_NOW "$NOW"
        echo "exec python3 $(q "$LIB/crontab") \"\$@\""
        ;;
      cron-run)
        [ -z "$USER_NAME" ] || default LM_CRON_USER "$USER_NAME"
        [ -z "$NOW" ] || default LM_CRON_NOW "$NOW"
        echo 'case " $* " in *" --root "*|*" --root="*) exec python3 '"$(q "$LIB/cron-run")"' "$@" ;; esac'
        echo "exec python3 $(q "$LIB/cron-run") --root $(q "$SANDBOX") --spool $(q "$SPOOL") \"\$@\""
        ;;
      cron-expand)
        [ -z "$NOW" ] || default LM_CRON_NOW "$NOW"
        echo "exec python3 $(q "$LIB/cron-expand") \"\$@\""
        ;;
      *)
        echo "exec python3 $(q "$LIB/$tool") \"\$@\""
        ;;
    esac
  } > "$BIN/$tool"
  chmod 755 "$BIN/$tool"
done
