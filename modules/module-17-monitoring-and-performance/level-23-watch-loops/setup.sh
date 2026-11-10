#!/bin/bash
# The target is a bash script literally named "etl job (v2)": the kernel uses the file
# name as the process name (comm), so /proc/PID/stat starts with "PID (etl job (v2)) S ...".
# It burns some CPU and grows a little every half second.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt .lm-state

cat > "opt/etl job (v2)" <<'LMEND'
#!/bin/bash
# nightly ETL job: transform, buffer, repeat
buf=()
while :; do
  i=0; while [ $i -lt 15000 ]; do i=$((i + 1)); done
  printf -v chunk '%*s' 40000 ''
  buf+=("$chunk")
  [ "${#buf[@]}" -gt 150 ] && buf=()
  sleep 0.5
done
LMEND
chmod +x "opt/etl job (v2)"
"$SANDBOX/opt/etl job (v2)" >/dev/null 2>&1 &
pid=$!
echo "$pid" > .lm-state/pid
sleep 1
[ -r "/proc/$pid/stat" ] || { echo "job did not start" >&2; exit 1; }
grep -q ') ' "/proc/$pid/stat" && head -c 60 "/proc/$pid/stat" | grep -q 'etl job (v2)' || { echo "unexpected comm" >&2; exit 1; }
