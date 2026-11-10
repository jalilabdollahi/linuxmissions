#!/bin/bash
# legacy-sync must be stopped now, not enabled, and masked (unit link to
# /dev/null in etc/systemd/system) so that report.service's Wants= cannot
# start it again. report.service and the vendor unit stay untouched, and
# report keeps running. When everything but the mask is done, a copy of the
# fake root is booted with the mock to show legacy-sync coming back.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC="$(dirname "$0")/../../../mocks/systemd/systemctl"
export LM_ROOT="$SANDBOX"
VENDOR=usr/lib/systemd/system/legacy-sync.service
MASK=etc/systemd/system/legacy-sync.service
WANTS=etc/systemd/system/multi-user.target.wants/legacy-sync.service

if [ ! -s .lm-state/units.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if ! cksum "$VENDOR" etc/systemd/system/report.service 2>/dev/null | cmp -s - .lm-state/units.sum; then
  echo "❌ the packaged legacy-sync.service in usr/lib or report.service was edited or removed; leave both files as they are (type 'reset' to restore them)"
  exit 1
fi
if [ "$(readlink etc/systemd/system/multi-user.target.wants/report.service)" != /etc/systemd/system/report.service ] ||
   [ "$("$SC" is-active report.service 2>/dev/null)" != active ]; then
  echo "❌ report.service must stay enabled and running; only legacy-sync is being retired"
  exit 1
fi

if pgrep -f "$SANDBOX/opt/legacy-sync/bin/legacy-sync" >/dev/null ||
   [ "$("$SC" is-active legacy-sync.service 2>/dev/null)" = active ]; then
  echo "❌ legacy-sync is still running right now"
  exit 1
fi
if [ -L "$WANTS" ]; then
  echo "❌ legacy-sync is still enabled: multi-user.target.wants/ links it into the boot"
  exit 1
fi

if [ "$(readlink "$MASK")" != /dev/null ]; then
  # Boot a throwaway copy of this server and see what comes up.
  SIM=.lm-state/boot-test
  rm -rf "$SIM"; mkdir -p "$SIM"
  cp -a bin etc usr opt var "$SIM"/ 2>/dev/null
  out=$(LM_ROOT="$SANDBOX/$SIM" LM_TIMESCALE=0.01 "$SC" mock-boot 2>&1)
  pkill -f "$SANDBOX/$SIM" 2>/dev/null
  sleep 0.1
  rm -rf "$SIM"
  if printf '%s\n' "$out" | grep -q 'Started legacy-sync.service'; then
    echo "❌ disabled and stopped, but a test boot of this server started legacy-sync.service again: another unit pulls it in"
  else
    echo "❌ legacy-sync.service is not masked"
  fi
  exit 1
fi

echo "✅ legacy-sync is stopped, disabled and masked: no boot and no Wants= can start it again"
exit 0
