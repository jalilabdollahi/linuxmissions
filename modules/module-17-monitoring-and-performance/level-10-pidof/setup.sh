#!/bin/bash
# opt/queue-worker.sh is started as an executable script, so its executable is
# /bin/bash, not "queue-worker.sh". healthcheck.sh uses plain `pidof queue-worker.sh` and always says
# DOWN. A decoy copy (queue-worker.bak) is running too, which breaks the
# "obvious" fix pgrep -f queue-worker.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt .lm-state

cat > opt/queue-worker.sh <<'LMEND'
#!/bin/bash
# queue worker: pops jobs from the queue (placeholder loop)
while :; do sleep 15; done
LMEND
cp opt/queue-worker.sh opt/queue-worker.bak
chmod +x opt/queue-worker.sh opt/queue-worker.bak

cat > healthcheck.sh <<'LMEND'
#!/bin/bash
# healthcheck.sh: run by cron every minute; a non-zero exit pages the on-call.
if pidof queue-worker.sh >/dev/null; then
  echo "queue-worker OK"
  exit 0
fi
echo "queue-worker DOWN"
exit 1
LMEND
chmod +x healthcheck.sh

"$SANDBOX/opt/queue-worker.sh" >/dev/null 2>&1 &
echo $! > .lm-state/worker.pid
"$SANDBOX/opt/queue-worker.bak" >/dev/null 2>&1 &
echo $! > .lm-state/bak.pid
sleep 0.5
