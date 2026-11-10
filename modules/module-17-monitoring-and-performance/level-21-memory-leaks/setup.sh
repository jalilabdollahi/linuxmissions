#!/bin/bash
# Four python workers: a big stable one, a mid-size stable one, a small one with a
# little jitter, and the leaker (smallest at the start, grows 60-140 KiB/s). Names and
# roles are shuffled per setup; the rate is random.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt .lm-state

cat > opt/worker.py <<'LMEND'
#!/usr/bin/env python3
# worker.py NAME : a service worker; its memory behaviour comes from .lm-state/roles
import os, random, sys, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
name = sys.argv[1]
roles = {l.split()[0]: l.split()[1:] for l in open(os.path.join(root, ".lm-state/roles"))}
role, arg = roles[name][0], int(roles[name][1])
hold = [b"\xa5" * (arg * 1024)]          # working set of `arg` KiB, really touched
t0 = time.time()
grown = 0
while True:
    if role == "leak":
        want = int(arg * 1024 * (time.time() - t0))
        if want - grown > 4096:
            hold.append(b"\xa5" * (want - grown))
            grown = want
    elif role == "jitter":
        tmp = b"\xa5" * (random.randint(0, 200) * 1024)   # transient buffer, freed again
        del tmp
    time.sleep(0.25)
LMEND

names=(ingest render mailer indexer exporter)
mapfile -t pick < <(printf '%s\n' "${names[@]}" | shuf | head -4)
rate=$((60 + RANDOM % 81))
mapfile -t spec < <(printf '%s\n' "stable $((60000 + RANDOM % 15000))" "stable $((28000 + RANDOM % 8000))" "jitter $((12000 + RANDOM % 4000))" "leak $rate" | shuf)
for i in 0 1 2 3; do echo "${pick[$i]} ${spec[$i]}"; done > .lm-state/roles
echo "$rate" > .lm-state/rate
: > .lm-state/pids
for n in "${pick[@]}"; do
  python3 "$SANDBOX/opt/worker.py" "$n" >/dev/null 2>&1 &
  echo "$n $!" >> .lm-state/pids
done
sleep 1.5
for n in "${pick[@]}"; do
  pid=$(awk -v n="$n" '$1==n {print $2}' .lm-state/pids)
  [ -d "/proc/$pid" ] || { echo "$n did not start" >&2; exit 1; }
done
ln=$(awk '$2=="leak" {print $1}' .lm-state/roles)
awk -v n="$ln" '$1==n {print $2}' .lm-state/pids > .lm-state/leaker
