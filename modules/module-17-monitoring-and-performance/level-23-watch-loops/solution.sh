#!/bin/bash
cat > sample.sh <<'LMEND'
#!/bin/bash
# usage: sample.sh PID N  ->  epoch,rss_kib,cpu_ticks, once per second
pid=$1; n=$2
for ((i = 0; i < n; i++)); do
  rest=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null) || exit 0
  rss=$(awk '/^VmRSS/ {print $2}' "/proc/$pid/status" 2>/dev/null)
  [ -n "$rest" ] && [ -n "$rss" ] || exit 0
  set -- $rest
  echo "$(date +%s),$rss,$((${12} + ${13}))"
  [ "$i" -lt $((n - 1)) ] && sleep 1
done
exit 0
LMEND
