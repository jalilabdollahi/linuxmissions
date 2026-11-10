#!/bin/bash
# diagnosis.txt must be one line "UNIT STATUS": the unit that is crash-looping
# (activating/auto-restart) and the exit status of its main process. The
# answer was picked at random by setup.sh and stored only as hashes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
FILE=diagnosis.txt

if [ ! -s .lm-state/unit.sha ] || [ ! -s .lm-state/code.sha ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -f "$FILE" ]; then
  echo "❌ diagnosis.txt does not exist yet"
  exit 1
fi

LINES=$(tr -d '\r' < "$FILE" | awk 'NF')
if [ -z "$LINES" ]; then
  echo "❌ diagnosis.txt is empty"
  exit 1
fi
if [ "$(printf '%s\n' "$LINES" | wc -l)" -ne 1 ]; then
  echo "❌ diagnosis.txt must hold exactly one line: the broken unit and its exit status"
  exit 1
fi
set -- $LINES
if [ $# -ne 2 ]; then
  echo "❌ the line must be 'UNIT STATUS', e.g. 'example.service 3'"
  exit 1
fi
UNIT=$1
CODE=${2%%/*}            # accept "78" as well as "78/CONFIG"
case $UNIT in *.service) ;; *) UNIT="$UNIT.service" ;; esac
case $CODE in ''|*[!0-9]*) echo "❌ '$2' is not an exit status; it is the number after status= on the Main PID line"; exit 1 ;; esac

sha() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }

if [ "$(sha "$UNIT")" != "$(cat .lm-state/unit.sha)" ]; then
  case $UNIT in
    nightly-export.service)
      echo "❌ nightly-export.service is a oneshot job that finished with status 0/SUCCESS; 'inactive (dead)' is what a finished oneshot looks like" ;;
    billing-api.service|order-worker.service|search-indexer.service|notify-gateway.service)
      echo "❌ $UNIT is not the broken one; look for a unit that never reaches 'active (running)'" ;;
    *)
      echo "❌ there is no unit called $UNIT on app-02; list the service units first" ;;
  esac
  exit 1
fi
if [ "$(sha "$CODE")" != "$(cat .lm-state/code.sha)" ]; then
  echo "❌ $UNIT is the right unit, but $CODE is not the exit status of its main process"
  exit 1
fi

echo "✅ $UNIT is crash-looping: its main process exits with status $CODE and systemd restarts it every 5 seconds"
exit 0
