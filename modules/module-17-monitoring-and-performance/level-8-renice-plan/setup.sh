#!/bin/bash
# Running batch workers. Violators (NI < 10): batch-report, batch-api-sync,
# batch-thumbs and the three-process batch-etl pipeline (one process group:
# batch-etl.sh with batch-etl-extract.sh and batch-etl-load.sh as children).
# Compliant: batch-cleanup (NI 16-19) and batch-mailer (NI 10-14), which must not
# change, plus api-server (NI 0) and metrics-agent (NI 5). Every worker is its own
# session/process group, so `renice -g` only hits what the player intends.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/jobs opt/svc .lm-state

idle() { printf '#!/bin/bash\n# %s (placeholder loop)\nwhile :; do sleep 20; done\n' "$2" > "$1"; }
for n in batch-report batch-api-sync batch-thumbs batch-cleanup batch-mailer batch-etl-extract batch-etl-load; do
  idle "opt/jobs/$n.sh" "$n"
done
cat > opt/jobs/batch-etl.sh <<LMEND
#!/bin/bash
# batch-etl: pipeline head, starts its two stages
bash "$SANDBOX/opt/jobs/batch-etl-extract.sh" &
bash "$SANDBOX/opt/jobs/batch-etl-load.sh" &
while :; do sleep 20; done
LMEND
idle opt/svc/api-server.sh api-server
idle opt/svc/metrics-agent.sh metrics-agent

pick() { local a=("$@"); echo "${a[$((RANDOM % ${#a[@]}))]}"; }
declare -A NI
NI[batch-report]=$(pick 0 0 3)
NI[batch-api-sync]=0
NI[batch-thumbs]=$(pick 5 7 9)
NI[batch-etl]=$(pick 0 2 4)
NI[batch-cleanup]=$(pick 16 17 18 19)
NI[batch-mailer]=$(pick 10 12 14)

start() {   # name ni dir
  setsid nice -n "$2" bash "$SANDBOX/$3/$1.sh" >/dev/null 2>&1 &
}
for n in batch-report batch-api-sync batch-thumbs batch-etl batch-cleanup batch-mailer; do
  start "$n" "${NI[$n]}" opt/jobs
done
start api-server 0 opt/svc
start metrics-agent 5 opt/svc
sleep 1

: > .lm-state/procs
rec() {   # name role dir ni
  local pid
  pid=$(pgrep -f "$SANDBOX/$3/$1\\.sh\$" | head -1)
  [ -n "$pid" ] || { echo "$1 did not start" >&2; exit 1; }
  echo "$pid $2 $1 $4" >> .lm-state/procs
}
for n in batch-report batch-api-sync batch-thumbs batch-etl; do rec "$n" violator opt/jobs "${NI[$n]}"; done
rec batch-etl-extract violator opt/jobs "${NI[batch-etl]}"
rec batch-etl-load violator opt/jobs "${NI[batch-etl]}"
rec batch-cleanup keep opt/jobs "${NI[batch-cleanup]}"
rec batch-mailer keep opt/jobs "${NI[batch-mailer]}"
rec api-server api opt/svc 0
rec metrics-agent agent opt/svc 5
