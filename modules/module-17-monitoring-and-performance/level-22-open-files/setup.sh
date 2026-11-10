#!/bin/bash
# Four python services with different soft limits. The leaker holds sockets up to a few
# descriptors short of its (random) soft limit (hard limit is higher, to separate soft
# from hard); a files service has more descriptors but a far higher limit; a pipe
# service and a small socket service are nowhere near theirs. Names are shuffled.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt data log .lm-state

cat > opt/svc.py <<'LMEND'
#!/usr/bin/env python3
# svc.py NAME : service; role, limit and number of descriptors come from .lm-state/roles
import os, resource, socket, sys, time
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
name = sys.argv[1]
roles = {l.split()[0]: l.split()[1:] for l in open(os.path.join(root, ".lm-state/roles"))}
kind, soft, hard, count = roles[name][0], int(roles[name][1]), int(roles[name][2]), int(roles[name][3])
cur_hard = resource.getrlimit(resource.RLIMIT_NOFILE)[1]
hard = min(hard, cur_hard) if cur_hard != resource.RLIM_INFINITY else hard
resource.setrlimit(resource.RLIMIT_NOFILE, (min(soft, hard), hard))
held = [open(os.path.join(root, "log", name + ".log"), "a")]
for i in range(count):
    if kind == "socket":
        held.append(socket.socket())
    elif kind == "pipe":
        held.extend(os.pipe())
    else:
        held.append(open(os.path.join(root, "data", f"{name}-{i}.dat"), "a"))
while True:
    time.sleep(3600)
LMEND

names=(api-gateway billing-worker session-store search-indexer notifier)
mapfile -t pick < <(printf '%s\n' "${names[@]}" | shuf | head -4)
limits=(128 192 256 384)
L=${limits[RANDOM % 4]}
k=$((4 + RANDOM % 5))                  # descriptors short of the limit
leak_count=$((L - k - 4))              # + std fds 0-2 (3) + log file (1) = L - k in total
mapfile -t spec < <(printf '%s\n' \
  "socket $L 4096 $leak_count" \
  "file 4096 4096 $((520 + RANDOM % 80))" \
  "pipe 1024 1024 $((60 + RANDOM % 30))" \
  "socket 256 256 $((20 + RANDOM % 20))" | shuf)
for i in 0 1 2 3; do echo "${pick[$i]} ${spec[$i]}"; done > .lm-state/roles
: > .lm-state/pids
for n in "${pick[@]}"; do
  python3 "$SANDBOX/opt/svc.py" "$n" >/dev/null 2>&1 &
  echo "$n $!" >> .lm-state/pids
done
sleep 1.5
for n in "${pick[@]}"; do
  pid=$(awk -v n="$n" '$1==n {print $2}' .lm-state/pids)
  [ -d "/proc/$pid" ] || { echo "$n did not start" >&2; exit 1; }
done
# the leaker is the socket service with the big descriptor count relative to its limit
ln=$(awk '$2=="socket" {print $1, $5}' .lm-state/roles | sort -k2 -n | tail -1 | cut -d' ' -f1)
pid=$(awk -v n="$ln" '$1==n {print $2}' .lm-state/pids)
echo "$pid" > .lm-state/leaker
echo "$L" > .lm-state/limit
real=$(ls /proc/$pid/fd | wc -l)
[ "$real" -ge $((L - 10)) ] && [ "$real" -lt "$L" ] || { echo "leaker has $real fds for limit $L" >&2; exit 1; }
