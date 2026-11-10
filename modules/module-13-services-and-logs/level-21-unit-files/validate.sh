#!/bin/bash
# etc/systemd/system/report-api.service: passes systemd-analyze verify, is
# enabled (wants link), Restart=on-failure, and is running as a systemd
# service: its main process writes the health file with the ticket's port.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC=bin/systemctl
U=report-api.service
F=etc/systemd/system/$U

if [ ! -s .lm-state/port ] || [ ! -x opt/report-api/bin/report-api ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
PORT=$(cat .lm-state/port)

if [ ! -f "$F" ]; then
  echo "❌ $F does not exist yet"
  exit 1
fi
out=$(bin/systemd-analyze verify "$F" 2>&1) || {
  echo "❌ systemd-analyze verify rejects the unit: $(echo "$out" | head -1)"
  exit 1
}
if [ -n "$out" ] && echo "$out" | grep -qiE 'unknown|ignoring|error'; then
  echo "❌ systemd-analyze verify complains: $(echo "$out" | head -1)"
  exit 1
fi
if [ "$($SC show -P LoadState $U 2>/dev/null)" != loaded ]; then
  echo "❌ systemd has not loaded $U (LoadState=$($SC show -P LoadState $U 2>/dev/null)); daemon-reload?"
  exit 1
fi
if $SC status $U 2>&1 | grep -q 'changed on disk'; then
  echo "❌ $U changed on disk since systemd loaded it (daemon-reload, then restart)"
  exit 1
fi
if [ "$(readlink etc/systemd/system/multi-user.target.wants/$U 2>/dev/null)" != /etc/systemd/system/$U ]; then
  echo "❌ $U is not enabled for boot: no link in multi-user.target.wants"
  exit 1
fi
rs=$($SC show -P Restart $U)
if [ "$rs" != on-failure ]; then
  echo "❌ Restart=$rs; the ticket wants the service restarted when it fails"
  exit 1
fi

sleep 1.2
st=$($SC show -P ActiveState $U)
pid=$($SC show -P MainPID $U)
if [ "$st" != active ] || [ "$pid" = 0 ] || [ ! -d /proc/$pid ]; then
  res=$($SC show -P Result $U)
  extra="look at systemctl status and the journal"
  [ "$st" = inactive ] && [ "$res" = success ] && extra="its main process exited cleanly right after it started; does the program stay in the foreground the way systemd expects?"
  echo "❌ $U is not running ($st, Result=$res); $extra"
  exit 1
fi
health=$(cat var/run/report-api/health 2>/dev/null)
case $health in
  "pid=$pid port=$PORT cwd=/opt/report-api"|"pid=$pid port=$PORT cwd=$SANDBOX/opt/report-api") ;;
  "pid=$pid "*) echo "❌ the service runs, but its health file says '${health#pid=$pid }'; expected port $PORT in /opt/report-api"; exit 1 ;;
  *) echo "❌ the health file is not written by the service's main process (PID $pid); is something else running report-api?"; exit 1 ;;
esac
echo "✅ $U is enabled, passes systemd-analyze verify, and runs as PID $pid on port $PORT"
exit 0
