SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/pid ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s sample.sh ] || { echo "❌ sample.sh is missing or empty"; exit 1; }
pid=$(cat .lm-state/pid)
[ -r /proc/$pid/stat ] || { echo "❌ the ETL job (PID $pid) is gone; type 'reset'"; exit 1; }
ticks() { sed 's/.*) //' /proc/$1/stat | awk '{print $12 + $13}'; }
rss() { awk '/^VmRSS/ {print $2}' /proc/$1/status; }
n=$((3 + RANDOM % 3))
t0=$(ticks $pid); r0=$(rss $pid); e0=$(date +%s)
timeout 20 bash sample.sh "$pid" "$n" > .lm-state/out 2> .lm-state/err
rc=$?
t1=$(ticks $pid); r1=$(rss $pid); e1=$(date +%s)
if [ "$rc" != 0 ]; then echo "❌ sample.sh $pid $n exited with status $rc"; exit 1; fi
if [ -s .lm-state/err ]; then echo "❌ sample.sh printed errors on stderr: $(head -1 .lm-state/err | cut -c1-90)"; exit 1; fi
rows=$(wc -l < .lm-state/out)
if [ "$rows" != "$n" ]; then echo "❌ asked for $n samples, got $rows lines"; exit 1; fi
lo=$(( (r0 < r1 ? r0 : r1) * 85 / 100 )); hi=$(( (r0 > r1 ? r0 : r1) * 115 / 100 ))
prev_e=0; prev_c=0; i=0
while IFS=, read -r e r c extra; do
  i=$((i+1))
  case "$e$r$c" in ''|*[!0-9]*) echo "❌ line $i is not 'epoch,rss_kib,cpu_ticks' with plain numbers: $(sed -n "${i}p" .lm-state/out | cut -c1-60)"; exit 1;; esac
  if [ -n "$extra" ] || [ -z "$c" ]; then echo "❌ line $i must have exactly three comma-separated fields"; exit 1; fi
  if [ "$i" -eq 1 ]; then
    if [ "$e" -lt "$e0" ] || [ "$e" -gt $((e1)) ]; then echo "❌ the epoch in line 1 ($e) is not the time of the sampling (date +%s)"; exit 1; fi
  else
    d=$((e - prev_e))
    if [ "$d" -lt 1 ]; then echo "❌ epochs must be strictly increasing: line $i is not later than line $((i-1)); sleep 1 between samples"; exit 1; fi
    if [ "$d" -gt 2 ]; then echo "❌ samples are $d s apart at line $i, expected about 1 s"; exit 1; fi
  fi
  if [ "$r" -lt "$lo" ] || [ "$r" -gt "$hi" ]; then echo "❌ rss_kib in line $i ($r) does not match VmRSS of the process (about $r1 KiB)"; exit 1; fi
  if [ "$c" -lt "$t0" ] || [ "$c" -gt "$t1" ] || [ "$c" -lt "$prev_c" ]; then
    echo "❌ cpu_ticks in line $i ($c) is not utime+stime of the process (/proc/PID/stat fields 14 and 15; it was between $t0 and $t1 during the run); is the process name with its spaces shifting your columns?"; exit 1
  fi
  prev_e=$e; prev_c=$c
done < .lm-state/out
if [ "$prev_c" -le "$t0" ]; then echo "❌ cpu_ticks never changed over $n samples, but the job is busy"; exit 1; fi
# the process disappears mid-run
sleep 600 &
victim=$!
bash sample.sh "$victim" 8 > .lm-state/out2 2> .lm-state/err2 &
sp=$!
sleep 2.5
kill "$victim" 2>/dev/null; wait "$victim" 2>/dev/null
for _ in $(seq 1 40); do kill -0 "$sp" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$sp" 2>/dev/null; then
  kill "$sp" 2>/dev/null
  echo "❌ sample.sh kept running after the process it watches was gone"; exit 1
fi
wait "$sp"; rc2=$?
if [ "$rc2" != 0 ]; then echo "❌ when the PID vanished, sample.sh exited with status $rc2 instead of 0"; exit 1; fi
if [ -s .lm-state/err2 ]; then echo "❌ when the PID vanished, sample.sh printed errors: $(head -1 .lm-state/err2 | cut -c1-90)"; exit 1; fi
bad=$(grep -vcE '^[0-9]+,[0-9]+,[0-9]+$' .lm-state/out2)
if [ "$bad" -gt 0 ]; then echo "❌ when the PID vanished, sample.sh printed a broken line: $(grep -vE '^[0-9]+,[0-9]+,[0-9]+$' .lm-state/out2 | head -1 | cut -c1-60)"; exit 1; fi
rows2=$(wc -l < .lm-state/out2)
if [ "$rows2" -lt 1 ] || [ "$rows2" -gt 4 ]; then echo "❌ the vanishing process lived about 2.5 s, but sample.sh printed $rows2 lines for it"; exit 1; fi
echo "✅ sample.sh samples once per second, parses the name with spaces correctly and stops cleanly when the process is gone"
exit 0
