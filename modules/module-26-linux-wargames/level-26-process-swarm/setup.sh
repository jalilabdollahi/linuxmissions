#!/bin/bash
# Wargame 26: a respawning swarm (own session/process group) with one member
# disguised as a kernel thread, next to three legitimate app processes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf opt .lm hidden.txt
mkdir -p opt/app opt/swarm/lib .lm
BASH_BIN=$(command -v bash)
ln -s "$BASH_BIN" opt/app/app
ln -s "$BASH_BIN" opt/swarm/swarmd
ln -s "$BASH_BIN" opt/swarm/lib/crunch
HID="$SANDBOX/opt/swarm/lib/.$(head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
mkdir -p "$HID"; cp "$BASH_BIN" "$HID/kw"

cat > opt/app/app.sh <<'S'
#!/bin/bash
# legitimate customer-facing worker
while :; do sleep 1; done
S
cat > opt/swarm/lib/crunch.sh <<'S'
#!/bin/bash
while :; do for i in $(seq 1 60); do :; done; sleep 0.2; done
S
cp opt/swarm/lib/crunch.sh opt/swarm/lib/kw.sh
cat > opt/swarm/swarmd.sh <<'S'
#!/bin/bash
# swarm supervisor: keeps N members alive, respawns any that die
SW="$1"; N="$2"; HID="$3"; DIS="$4"; SLOT="$5"
declare -a pid
dead() { [ -z "$1" ] || ! kill -0 "$1" 2>/dev/null || grep -q '^State:.*Z' "/proc/$1/status" 2>/dev/null; }
while :; do
  for s in $(seq 1 "$N"); do
    if dead "${pid[$s]}"; then
      if [ "$s" = "$SLOT" ]; then
        ( exec -a "$DIS" "$HID/kw" "$SW/lib/kw.sh" "$s" ) >/dev/null 2>&1 &
      else
        "$SW/lib/crunch" "$SW/lib/crunch.sh" "$s" >/dev/null 2>&1 &
      fi
      pid[$s]=$!
    fi
  done
  sleep 0.3
done
S

N=$((6 + RANDOM % 4)); SLOT=$((1 + RANDOM % N))
DIS=$(shuf -n1 -e '[kworker/0:1]' '[kworker/u8:3]' '[ksoftirqd/1]' '[kswapd0]' '[rcu_sched]')
: > .lm/app.pids
for i in 1 2 3; do
  setsid "$SANDBOX/opt/app/app" "$SANDBOX/opt/app/app.sh" "$i" >/dev/null 2>&1 &
  echo "$! $i" >> .lm/app.pids
done
setsid "$SANDBOX/opt/swarm/swarmd" "$SANDBOX/opt/swarm/swarmd.sh" "$SANDBOX/opt/swarm" "$N" "$HID" "$DIS" "$SLOT" >/dev/null 2>&1 &
echo "$!" > .lm/swarmd.pid
echo "$(readlink -f "$HID/kw")" > .lm/hidden
sleep 1.5
exit 0
