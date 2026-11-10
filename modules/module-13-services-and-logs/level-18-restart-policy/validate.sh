#!/bin/bash
# queue-consumer.service must have the ticket's values (Restart=on-failure,
# RestartSec, StartLimitBurst, StartLimitIntervalSec). Then the validator
# replays the broker blip (BLIPS failures in a row, sped up with
# LM_TIMESCALE): the unit must come through it still running with
# NRestarts == BLIPS, and after a `drain` (exit 0) it must stay stopped.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC=bin/systemctl
U=queue-consumer.service

if [ ! -s .lm-state/want ] || [ ! -x opt/queue/bin/queue-consumer ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
. .lm-state/want
if ! sha256sum -c --quiet .lm-state/sha >/dev/null 2>&1; then
  echo "❌ opt/queue/bin/queue-consumer (or the broker script) was modified; the unit has to be fixed, not the program"
  exit 1
fi
if [ "$($SC show -P LoadState $U 2>/dev/null)" != loaded ]; then
  echo "❌ $U does not load; check systemctl status $U"
  exit 1
fi
if $SC status $U 2>&1 | grep -q 'changed on disk'; then
  echo "❌ $U changed on disk; systemd still runs the old definition (daemon-reload)"
  exit 1
fi

restart=$($SC show -P Restart $U)
case $restart in
  on-failure) ;;
  always|on-success) echo "❌ Restart=$restart also restarts the service after a clean exit 0 (the operators' drain); the ticket wants restarts only after failures"; exit 1 ;;
  *) echo "❌ Restart=$restart: the service must be restarted after failures"; exit 1 ;;
esac
got=$($SC show -P RestartUSec $U)
if [ "$got" != "$RESTARTUSEC" ]; then
  echo "❌ systemctl show says RestartUSec=$got, the ticket wants ${RESTARTSEC}s between attempts"
  exit 1
fi
got=$($SC show -P StartLimitBurst $U)
if [ "$got" != "$BURST" ]; then
  echo "❌ StartLimitBurst is $got, the ticket allows $BURST starts"
  exit 1
fi
got=$($SC show -P StartLimitIntervalUSec $U)
if [ "$got" != "$INTERVALUSEC" ]; then
  echo "❌ StartLimitIntervalUSec is $got, the ticket wants ${INTERVALSEC}s"
  exit 1
fi
if [ "$($SC is-enabled $U 2>/dev/null)" != enabled ]; then
  echo "❌ $U is no longer enabled"
  exit 1
fi

# Replay: BLIPS failures in a row, then the broker is back.
$SC stop $U >/dev/null 2>&1
rm -f var/lib/queue/drain
echo 0 > var/lib/queue/pos
$SC reset-failed $U >/dev/null 2>&1
LM_TIMESCALE=0.02 $SC start $U >/dev/null 2>&1
ok=
for _ in $(seq 1 150); do
  st=$($SC show -P ActiveState $U)
  nr=$($SC show -P NRestarts $U)
  if [ "$st" = failed ]; then break; fi
  if [ "$st" = active ] && [ "$nr" = "$BLIPS" ]; then ok=1; break; fi
  sleep 0.1
done
if [ -z "$ok" ]; then
  res=$($SC show -P Result $U)
  if [ "$res" = start-limit-hit ]; then
    echo "❌ replaying the broker blip ($BLIPS failures in a row): $U ends in start-limit-hit again; it needs more room, or more time between attempts"
  else
    echo "❌ replaying the broker blip ($BLIPS failures in a row): $U ends $st (Result=$res, NRestarts=$nr), not running"
  fi
  exit 1
fi
sleep 0.5
if [ "$($SC show -P ActiveState $U)" != active ]; then
  echo "❌ $U did not stay up after the blip"
  exit 1
fi

# The operator drains it: exit 0 on purpose.
touch var/lib/queue/drain
for _ in $(seq 1 40); do
  [ "$($SC show -P ActiveState $U)" != active ] && break
  sleep 0.1
done
sleep 1.5
st=$($SC show -P ActiveState $U)
if [ "$st" != inactive ]; then
  echo "❌ after the drain (exit 0) the service is $st: it came back, but a clean exit must stay stopped"
  exit 1
fi
res=$($SC show -P Result $U)
if [ "$res" != success ]; then
  echo "❌ after the drain the unit shows Result=$res, expected success"
  exit 1
fi

# leave it running, as the ticket asks
echo "$((BLIPS + 1))" > var/lib/queue/pos
$SC reset-failed $U >/dev/null 2>&1
$SC start $U >/dev/null 2>&1
if [ "$($SC is-active $U)" != active ]; then
  echo "❌ $U could not be started again after the drain"
  exit 1
fi
echo "✅ $U rode out $BLIPS broker failures (RestartSec=${RESTARTSEC}s, $BURST starts per ${INTERVALSEC}s), stays stopped after a clean exit, and is running"
exit 0
