#!/bin/bash
# Six batch workers (scripts opt/jobs/batch-*.sh) started with different
# niceness, the API (opt/svc/api-server.sh, NI 0) and a monitoring agent (NI 5,
# not a batch worker). batch-api-sync always runs at 0 (a violator whose name
# contains "api"); one worker sits at exactly 9 (violator), one at exactly 10 (fine).
# Which worker gets which niceness is random. Roles in .lm-state/procs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/jobs opt/svc .lm-state

workers=(batch-report batch-thumbs batch-etl batch-api-sync batch-cleanup batch-mailer)
for n in "${workers[@]}" ; do
  cat > "opt/jobs/$n.sh" <<LMEND
#!/bin/bash
# $n: nightly batch worker (placeholder loop)
while :; do sleep 20; done
LMEND
done
cat > opt/svc/api-server.sh <<'LMEND'
#!/bin/bash
# customer-facing API (placeholder loop)
while :; do sleep 20; done
LMEND
cat > opt/svc/metrics-agent.sh <<'LMEND'
#!/bin/bash
# monitoring agent (placeholder loop)
while :; do sleep 20; done
LMEND

# niceness table: api-sync = 0, one 9, one 10, three random from the rest
others=(batch-report batch-thumbs batch-etl batch-cleanup batch-mailer)
mapfile -t others < <(printf '%s\n' "${others[@]}" | shuf)
declare -A NI
NI[batch-api-sync]=0
NI[${others[0]}]=9
NI[${others[1]}]=10
pool=(0 2 5 12 15 19)
for i in 2 3 4; do NI[${others[$i]}]=${pool[$((RANDOM % 6))]}; done

: > .lm-state/procs
for n in "${workers[@]}"; do
  nice -n "${NI[$n]}" bash "$SANDBOX/opt/jobs/$n.sh" >/dev/null 2>&1 &
  echo "$! worker $n ${NI[$n]}" >> .lm-state/procs
done
nice -n 0 bash "$SANDBOX/opt/svc/api-server.sh" >/dev/null 2>&1 &
echo "$! api api-server 0" >> .lm-state/procs
nice -n 5 bash "$SANDBOX/opt/svc/metrics-agent.sh" >/dev/null 2>&1 &
echo "$! agent metrics-agent 5" >> .lm-state/procs
sleep 0.5
