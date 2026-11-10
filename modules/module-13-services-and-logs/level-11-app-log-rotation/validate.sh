#!/bin/bash
# etc/logrotate.d/app must rotate both logs so that the running app moves on to
# the new files: no copytruncate (the README forbids it), a postrotate that
# makes the app reopen its logs, exactly once per rotation (sharedscripts).
# When the config looks plausible, the validator forces a real rotation with
# its own state file (PATH has the sandbox's bin/ first, like the game
# shell) and watches the files: new lines must land in the new app.log and
# audit.log, the .1 files must stop growing, and the app must have been
# signalled exactly once.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC="$(dirname "$0")/../../../mocks/systemd/systemctl"
export LM_ROOT="$SANDBOX"
CONF=etc/logrotate.d/app
D=var/log/app

if [ ! -f "$CONF" ]; then
  echo "❌ etc/logrotate.d/app is missing"
  exit 1
fi
PID=$("$SC" show -P MainPID app.service 2>/dev/null)
if [ "$("$SC" is-active app.service 2>/dev/null)" != active ] || [ -z "$PID" ] || [ "$PID" = 0 ]; then
  echo "❌ app.service is not running"
  exit 1
fi

body=$(sed 's/#.*//' "$CONF")
if printf '%s\n' "$body" | grep -qw copytruncate; then
  echo "❌ copytruncate is not allowed here: lines written between the copy and the truncate are lost (see opt/app/README)"
  exit 1
fi
if ! printf '%s\n' "$body" | grep -qw postrotate; then
  echo "❌ after a rotation the app goes on writing into the renamed file (compare ls -l /proc/$PID/fd with ls -li $D)"
  exit 1
fi
out=$(logrotate -d -s .lm-state/check.state "$CONF" 2>&1)
if printf '%s\n' "$out" | grep -q '^error:'; then
  echo "❌ logrotate reports an error in $CONF: $(printf '%s\n' "$out" | grep -m1 '^error:')"
  exit 1
fi

# Real rotation, then watch.
before=$(cat var/lib/app/hup-count 2>/dev/null || echo 0)
out=$(PATH="$SANDBOX/bin:$PATH" logrotate -s .lm-state/validate.state -f "$CONF" 2>&1)
if printf '%s\n' "$out" | grep -q 'error'; then
  echo "❌ the forced rotation failed: $(printf '%s\n' "$out" | grep -m1 error)"
  exit 1
fi
sleep 1.5
after=$(cat var/lib/app/hup-count 2>/dev/null || echo 0)
s1_app=$(stat -c %s "$D/app.log.1" 2>/dev/null || echo 0)
s1_aud=$(stat -c %s "$D/audit.log.1" 2>/dev/null || echo 0)
n_app=$(stat -c %s "$D/app.log" 2>/dev/null || echo 0)
n_aud=$(stat -c %s "$D/audit.log" 2>/dev/null || echo 0)
sleep 1.2
s2_app=$(stat -c %s "$D/app.log.1" 2>/dev/null || echo 0)
s2_aud=$(stat -c %s "$D/audit.log.1" 2>/dev/null || echo 0)
m_app=$(stat -c %s "$D/app.log" 2>/dev/null || echo 0)
m_aud=$(stat -c %s "$D/audit.log" 2>/dev/null || echo 0)

if [ "$after" -eq "$before" ]; then
  echo "❌ I forced a rotation: the files were renamed, but the app was not told to reopen them (its postrotate didn't reach it)"
  exit 1
fi
if [ $((after - before)) -gt 1 ]; then
  echo "❌ I forced a rotation and the app was reloaded $((after - before)) times: postrotate ran once per log file. One reload per rotation is enough"
  exit 1
fi
if [ "$s2_app" -ne "$s1_app" ] || [ "$s2_aud" -ne "$s1_aud" ]; then
  echo "❌ after a forced rotation the app still writes into the rotated .1 files"
  exit 1
fi
if [ "$m_app" -le "$n_app" ] || [ "$m_aud" -le "$n_aud" ]; then
  echo "❌ after a forced rotation the new app.log and audit.log don't receive the app's lines"
  exit 1
fi
if ! ls -l "/proc/$PID/fd" 2>/dev/null | grep -q "$D/app.log$"; then
  echo "❌ the app's open files don't point at the new $D/app.log"
  exit 1
fi

echo "✅ a forced rotation renamed both logs, the app reopened them once, and new lines go to the new files"
exit 0
