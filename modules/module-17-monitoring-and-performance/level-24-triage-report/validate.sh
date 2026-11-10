SANDBOX="$1"
cd "$SANDBOX" || exit 1
SANDBOX=$(pwd -P)
if [ ! -s .lm-state/pids ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
pid_of() { awk -v n="$1" '$1==n {print $2}' .lm-state/pids; }
alive() { [ -r /proc/$1/status ] && [ "$(ps -o stat= -p "$1" 2>/dev/null | cut -c1)" != Z ]; }
ni_of() { ps -o ni= -p "$1" 2>/dev/null | tr -d ' '; }
[ -s triage.env ] || { echo "❌ triage.env is missing or empty"; exit 1; }
get() { grep -E "^$1=" triage.env | tail -1 | cut -d= -f2- | tr -d ' \t\r'; }
for k in SPAWNER_PID LEAKER_PID LEAKER_RSS_KIB STUCK_PORT LOGWRITER_PID; do
  v=$(get $k)
  [ -n "$v" ] || { echo "❌ triage.env has no $k= line"; exit 1; }
  case $v in *[!0-9]*) echo "❌ $k must be a plain number"; exit 1;; esac
done
# --- findings
sp=$(get SPAWNER_PID)
if [ "$sp" != "$(pid_of spawner)" ]; then
  echo "❌ SPAWNER_PID is wrong: it must be the long-running parent whose children burn CPU (not a child, not another busy process)"; exit 1
fi
lp=$(get LEAKER_PID)
if [ "$lp" != "$(pid_of leaker)" ]; then
  if [ "$lp" = "$(pid_of api)" ]; then
    echo "❌ LEAKER_PID is the API server: it is the biggest process but its memory is stable; look for the one that keeps growing"
  else
    echo "❌ LEAKER_PID is wrong: the leaker is the process whose RSS keeps growing"
  fi
  exit 1
fi
rss=$(get LEAKER_RSS_KIB)
lo=$(awk 'NR==1 {print $2}' .lm-state/leaker.rss)
hi=$(tail -1 .lm-state/leaker.rss | awk '{print $2}')
if [ "$rss" -lt $((lo * 95 / 100)) ] || [ "$rss" -gt $((hi * 105 / 100)) ]; then
  echo "❌ LEAKER_RSS_KIB=$rss is not the resident memory of the leaker (VmRSS in KiB, read before you stop it)"; exit 1
fi
port=$(get STUCK_PORT)
if [ "$port" != "$(cat .lm-state/port-queue)" ]; then
  if [ "$port" = "$(cat .lm-state/port-api)" ]; then
    echo "❌ STUCK_PORT is the API server's port: its accept queue is empty; look for Recv-Q above Send-Q"
  else
    echo "❌ STUCK_PORT is not the listener with the full accept queue"
  fi
  exit 1
fi
lw=$(get LOGWRITER_PID)
if [ "$lw" != "$(pid_of supervisor)" ] && ! grep -qx "$lw" .lm-state/writer.pids; then
  echo "❌ LOGWRITER_PID is not the process that writes the runaway log (or its supervisor)"; exit 1
fi
# --- collateral damage
for name in api audit queue; do
  alive "$(pid_of $name)" || { echo "❌ the $name process was stopped; it was healthy (or not yours to touch) and had to be left alone"; exit 1; }
done
[ "$(ni_of "$(pid_of api)")" = 0 ] || { echo "❌ the healthy API server was reniced; only the spawner should be"; exit 1; }
alive "$(pid_of agent)" || { echo "❌ metrics-agent was stopped; it was not part of the problem"; exit 1; }
# --- mitigations
alive "$(pid_of spawner)" || { echo "❌ the spawner is gone; it had to keep running, only reniced"; exit 1; }
n=$(ni_of "$(pid_of spawner)")
[ "$n" = 19 ] || { echo "❌ the spawner's nice value is $n, expected 19"; exit 1; }
if alive "$(pid_of leaker)"; then echo "❌ the leaker (PID $(pid_of leaker)) is still running"; exit 1; fi
if pgrep -f "$SANDBOX/opt/svc-supervisor.sh" >/dev/null; then
  echo "❌ the supervisor is still running; if you stop only the logger, it starts a new one a second later"; exit 1
fi
if pgrep -f "$SANDBOX/opt/log-forwarder.sh" >/dev/null; then
  echo "❌ the log writer is still running"; exit 1
fi
s1=$(stat -c %s log/forwarder.debug.log); sleep 2.5
s2=$(stat -c %s log/forwarder.debug.log)
if [ "$s2" != "$s1" ] || pgrep -f "$SANDBOX/opt/log-forwarder.sh" >/dev/null; then
  echo "❌ the runaway log is still growing: something restarted the writer"; exit 1
fi
echo "✅ all four culprits identified with evidence, mitigated in the right order, and the healthy services left alone"
exit 0
