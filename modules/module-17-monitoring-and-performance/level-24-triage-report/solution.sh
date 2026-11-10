#!/bin/bash
# findings
for i in $(seq 30); do ps -eo ppid=,pcpu=,args= | awk '$2 > 30 && /opt\// {print $1}'; sleep 0.1; done | sort | uniq -c | sort -rn | awk 'NR==1 {print $2}' > .sp
for p in $(pgrep -f 'opt/.*\.py'); do echo "$p $(awk '/^VmRSS/ {print $2}' /proc/$p/status)"; done > .r0; sleep 6
for p in $(pgrep -f 'opt/.*\.py'); do echo "$p $(awk '/^VmRSS/ {print $2}' /proc/$p/status)"; done > .r1
leaker=$(join .r0 .r1 | awk '{print $1, $3 - $2}' | sort -k2 -n | tail -1 | cut -d' ' -f1)
rss=$(awk '/^VmRSS/ {print $2}' /proc/$leaker/status)
port=$(ss -ltn | awk 'NR>1 && $2>$3 {n=split($4,a,":"); print a[n]}')
lw=$(fuser log/forwarder.debug.log 2>/dev/null | awk '{print $1}')
sup=$(ps -o ppid= -p "$lw" | tr -d ' ')
printf 'SPAWNER_PID=%s\nLEAKER_PID=%s\nLEAKER_RSS_KIB=%s\nSTUCK_PORT=%s\nLOGWRITER_PID=%s\n' "$(cat .sp)" "$leaker" "$rss" "$port" "$lw" > triage.env
# mitigation: spawner nice 19, leaker stopped after the RSS was recorded, supervisor before its child
renice -n 19 -p "$(cat .sp)" >/dev/null
kill "$leaker"
kill "$sup"; kill "$lw"
