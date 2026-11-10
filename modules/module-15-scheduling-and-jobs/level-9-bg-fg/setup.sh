#!/bin/bash
# Pause, Snapshot, Resume: export.sh logs a heartbeat per second and a CONT
# line when it is resumed; snapshot.sh refuses to run unless every export.sh
# is stopped (state T). Both log with $EPOCHREALTIME for the validator.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > export.sh <<'SH'
#!/bin/bash
# Stream the orders archive to the backup disk: 60 chunks, about one per second.
case "$0" in
  /*) ;;
  *) exec "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" "$@" ;;
esac
LOG="$(dirname "$0")/export.log"
trap 'echo "CONT $EPOCHREALTIME" >> "$LOG"' CONT
echo "START $$ $EPOCHREALTIME" >> "$LOG"
for ((chunk = 1; chunk <= 60; chunk++)); do
  sleep 1
  echo "beat $chunk $EPOCHREALTIME" >> "$LOG"
done
echo "DONE $EPOCHREALTIME" >> "$LOG"
SH

cat > snapshot.sh <<'SH'
#!/bin/bash
# Take a consistent snapshot of the backup disk (about 5 seconds).
# The disk must be quiet: every export.sh has to be paused first.
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG="$HERE/snapshot.log"
for pid in $(pgrep -f "$HERE/export\.sh"); do
  state="$(ps -o stat= -p "$pid" 2>/dev/null)"
  case "$state" in
    T*|"") ;;
    *) echo "snapshot: export.sh (PID $pid) is writing to the disk; pause it first" >&2
       echo "REFUSED $EPOCHREALTIME" >> "$LOG"
       exit 1 ;;
  esac
done
echo "start $EPOCHREALTIME" >> "$LOG"
echo "snapshot: freezing the backup volume ..."
sleep 5
echo "end $EPOCHREALTIME" >> "$LOG"
echo "snapshot: done, snap-$(date +%Y%m%d-%H%M%S) is consistent"
SH
chmod 755 export.sh snapshot.sh
: > export.log
: > snapshot.log
