#!/bin/bash
# Two supervisors (supervisor.sh A|B) each start six workers
# (worker.sh --queue=Q --id=N) from etc/supervisor-X.conf. Supervisor B runs 2-4
# `emails` workers plus one `emails-archive`; A runs 2-3 `emails` workers. Order
# and the other queues are random. Expected set: queue exactly `emails` AND
# parent = B.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt etc .lm-state

cat > opt/worker.sh <<'LMEND'
#!/bin/bash
# queue consumer (placeholder loop); usage: worker.sh --queue=NAME --id=N
while :; do sleep 20; done
LMEND
cat > opt/supervisor.sh <<'LMEND'
#!/bin/bash
# supervisor: starts one worker per line of etc/supervisor-NAME.conf ("queue id")
root=$(cd "$(dirname "$0")/.." && pwd)
while read -r queue id; do
  bash "$root/opt/worker.sh" --queue="$queue" --id="$id" &
done < "$root/etc/supervisor-$1.conf"
wait
LMEND

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
other = ["sms", "push", "billing", "reports", "webhooks"]
nb = R.randint(2, 4); na = R.randint(2, 3)
B = ["emails"] * nb + ["emails-archive"] + R.sample(other, 5 - nb)
A = ["emails"] * na + R.sample(other, 6 - na)
R.shuffle(A); R.shuffle(B)
ids = R.sample(range(1, 13), 12)
for name, qs in (("A", A), ("B", B)):
    with open("etc/supervisor-%s.conf" % name, "w") as f:
        for q in qs:
            f.write("%s %d\n" % (q, ids.pop()))
PY
bash "$SANDBOX/opt/supervisor.sh" A >/dev/null 2>&1 &
bash "$SANDBOX/opt/supervisor.sh" B >/dev/null 2>&1 &
sleep 1

supA=$(pgrep -f "$SANDBOX/opt/supervisor.sh A\$")
supB=$(pgrep -f "$SANDBOX/opt/supervisor.sh B\$")
[ -n "$supA" ] && [ -n "$supB" ] || { echo "supervisors did not start" >&2; exit 1; }
echo "A $supA" > .lm-state/sup
echo "B $supB" >> .lm-state/sup
: > .lm-state/workers
for X in A B; do
  while read -r q id; do
    pid=$(pgrep -f "worker.sh --queue=$q --id=$id\$" | head -1)
    [ -n "$pid" ] || { echo "worker $q $id did not start" >&2; exit 1; }
    echo "$pid $X $q" >> .lm-state/workers
  done < etc/supervisor-$X.conf
done
awk '$2=="B" && $3=="emails" {print $1}' .lm-state/workers | sort -n > .lm-state/want
