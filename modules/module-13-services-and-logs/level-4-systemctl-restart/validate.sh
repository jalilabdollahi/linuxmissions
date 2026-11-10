#!/bin/bash
# The api must run the deployed config revision in the SAME process as at
# setup (no restart), systemd must know how to reload it (ExecReload= that
# sends SIGHUP to $MAINPID, loaded with daemon-reload), and the reload must
# have gone through systemctl ("Reloaded api.service" in the journal).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC="$(dirname "$0")/../../../mocks/systemd/systemctl"
export LM_ROOT="$SANDBOX"
LOG=var/log/api/api.log

if [ ! -s .lm-state/api.pid ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
PID0=$(cat .lm-state/api.pid)
STATE=$("$SC" is-active api.service 2>/dev/null)
PID=$("$SC" show -P MainPID api.service 2>/dev/null)

if [ "$STATE" != active ]; then
  echo "❌ api.service is not running (it is '$STATE'); the export jobs it was running are gone. Type 'reset' to try again"
  exit 1
fi
if [ "$PID" != "$PID0" ]; then
  echo "❌ api was restarted (Main PID $PID0 is now $PID): its running export jobs were aborted. Type 'reset' to try again"
  exit 1
fi

if [ "$("$SC" show -P CanReload api.service 2>/dev/null)" != yes ]; then
  if grep -Eq '^[[:space:]]*ExecReload[[:space:]]*=' etc/systemd/system/api.service; then
    echo "❌ api.service on disk has ExecReload=, but systemd still uses the unit it loaded earlier (see the 'changed on disk' warning)"
  else
    echo "❌ systemctl can't reload api.service yet: 'Job type reload is not applicable'"
  fi
  exit 1
fi
RELOAD=$("$SC" show -P ExecReload api.service 2>/dev/null)
if ! printf '%s\n' "$RELOAD" | grep -Eq 'argv\[\]=[^;]*kill[^;]*(-HUP|-s HUP|-s SIGHUP|-SIGHUP|-1|--signal HUP|--signal=HUP)[^;]*\$\{?MAINPID'; then
  echo "❌ api.service's ExecReload= must send SIGHUP to the main process (\$MAINPID), as the api's README says"
  exit 1
fi

REV=$(sed -n 's/^revision[[:space:]]*=[[:space:]]*//p' etc/api/api.conf)
LOADED=$(grep "api-server\[$PID0\]: config revision " "$LOG" 2>/dev/null | tail -n 1 | sed 's/.*config revision \([^ ]*\).*/\1/')
if [ "$LOADED" != "$REV" ]; then
  echo "❌ api (PID $PID0) is still running config revision $LOADED; the deploy shipped revision $REV"
  exit 1
fi
if ! grep -qs 'Reloaded api.service' run/log/journal/*.json; then
  echo "❌ the api re-read its config, but not through systemd: 'systemctl reload api' has not succeeded yet"
  exit 1
fi

echo "✅ api (still PID $PID0, jobs untouched) runs config revision $REV, and 'systemctl reload api' works"
exit 0
