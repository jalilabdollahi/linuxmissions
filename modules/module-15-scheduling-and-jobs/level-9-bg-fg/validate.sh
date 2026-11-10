#!/bin/bash
# The last export run in export.log must be complete (beats 1..60, DONE),
# with one gap between heartbeats that has a CONT marker after it, and a
# full snapshot (start and end in snapshot.log) inside that gap.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
running=""
for pid in $(pgrep -f "$SANDBOX/export\.sh"); do
  running="$running $(ps -o stat= -p "$pid" 2>/dev/null | cut -c1)"
done

python3 - "$running" <<'PY'
import sys

states = sys.argv[1].split()
try:
    export = [l.split() for l in open("export.log") if l.strip()]
    snaps = [l.split() for l in open("snapshot.log") if l.strip()]
except OSError:
    print("❌ export.log or snapshot.log is missing; type reset to start over")
    sys.exit(1)

starts = [i for i, l in enumerate(export) if l[0] == "START"]
if not starts:
    print("❌ export.sh has not been started yet")
    sys.exit(1)
run = export[starts[-1]:]
beats = [(int(l[1]), float(l[2])) for l in run if l[0] == "beat"]
conts = [float(l[1]) for l in run if l[0] == "CONT"]
done = [l for l in run if l[0] == "DONE"]

# The snapshot must sit inside a pause of this run.
gaps = []
times = [float(run[0][2])] + [t for _, t in beats]
for a, b in zip(times, times[1:]):
    if b - a > 2.2:
        gaps.append((a, b))
complete = []
pending = None
for l in snaps:
    if l[0] == "start":
        pending = float(l[1])
    elif l[0] == "end" and pending is not None:
        complete.append((pending, float(l[1])))
        pending = None

if not done:
    if "T" in states:
        if any(s > float(run[0][2]) for s, _ in complete):
            print("❌ the export is still paused (Stopped); after the snapshot it has to continue in the background")
        else:
            print("❌ the export is paused; now take the snapshot")
    elif states:
        if not gaps:
            print("❌ the export is running but has not been paused yet")
        else:
            print("❌ the export is still running; wait for it to write DONE to export.log")
    else:
        print("❌ the last export run stopped before DONE (was it killed?); start it again and pause it instead")
    sys.exit(1)
if [n for n, _ in beats] != list(range(1, 61)):
    print("❌ the last export run's heartbeats are not 1..60 in order; let one run go from start to DONE")
    sys.exit(1)
if len(starts) > 1 and not gaps:
    print("❌ the export that finished was a fresh start with no pause; pause the running export instead of restarting it")
    sys.exit(1)
if not gaps:
    print("❌ export.log shows no pause: the heartbeats never stopped while the export ran")
    sys.exit(1)
if not complete:
    print("❌ snapshot.log has no finished snapshot; run snapshot.sh while the export is paused")
    sys.exit(1)
for start, end in complete:
    for a, b in gaps:
        if a < start and end < b and any(start < c <= b + 0.5 for c in conts):
            print(f"✅ the export paused for {b - a:.0f}s, the snapshot ran inside the pause, and the export finished")
            sys.exit(0)
if any(any(a < s and e < b for a, b in gaps) for s, e in complete):
    print("❌ the snapshot ran in a pause, but the export was not resumed with SIGCONT (no CONT in export.log)")
else:
    print("❌ no complete snapshot falls inside a pause of the export that finished; pause it, snapshot, then resume")
sys.exit(1)
PY
