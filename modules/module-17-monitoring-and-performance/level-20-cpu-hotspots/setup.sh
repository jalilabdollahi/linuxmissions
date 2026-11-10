#!/bin/bash
# Three parents that each spawn a child every 100 ms; only one parent's children burn
# CPU (~0.15 s each). Parent names are randomised per setup. Plus a steady low-CPU agent.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt .lm-state

names=(batch-scheduler report-ticker log-compactor session-reaper)
mapfile -t pick < <(printf '%s\n' "${names[@]}" | shuf | head -3)
heavy=${pick[0]}; light1=${pick[1]}; light2=${pick[2]}

mkparent() {   # name, child body
  cat > "opt/$1.sh" <<LMEND
#!/bin/bash
# $1: runs a step every 100 ms
root=\$(cd "\$(dirname "\$0")/.." && pwd)
while :; do
  bash "\$root/opt/$1-step.sh" &
  sleep 0.1
done
LMEND
  printf '#!/bin/bash\n# one unit of work for %s\n%s\n' "$1" "$2" > "opt/$1-step.sh"
}
mkparent "$heavy" 't=${EPOCHREALTIME/./}; end=$((t + 150000)); while [ "${EPOCHREALTIME/./}" -lt "$end" ]; do :; done'
mkparent "$light1" 'sleep 0.3'
mkparent "$light2" 'echo ok > /dev/null; sleep 0.2'
cat > opt/metrics-agent.sh <<'LMEND'
#!/bin/bash
# steady background agent: a little CPU every second
while :; do
  t=${EPOCHREALTIME/./}; end=$((t + 25000))
  while [ "${EPOCHREALTIME/./}" -lt "$end" ]; do :; done
  sleep 1
done
LMEND

: > .lm-state/pids
for n in "$heavy" "$light1" "$light2" metrics-agent; do
  bash "$SANDBOX/opt/$n.sh" >/dev/null 2>&1 &
  echo "$n $!" >> .lm-state/pids
done
echo "$(awk -v n="$heavy" '$1==n {print $2}' .lm-state/pids)" > .lm-state/answer
echo "$heavy" > .lm-state/heavy
sleep 1
for n in "$heavy" "$light1" "$light2" metrics-agent; do
  pid=$(awk -v n="$n" '$1==n {print $2}' .lm-state/pids)
  [ -d "/proc/$pid" ] || { echo "$n did not start" >&2; exit 1; }
done
