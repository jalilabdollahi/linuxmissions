#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/heavy.sh" <<'SCRIPT'
#!/bin/bash
# Batch job: crunch numbers in bursts. Gives up on its own after an hour.
while [ "$SECONDS" -lt 3600 ]; do
  i=0
  while [ "$i" -lt 100000 ]; do i=$((i + 1)); done
  sleep 0.2
done
SCRIPT
chmod +x "$SANDBOX/heavy.sh"

bash "$SANDBOX/heavy.sh" >/dev/null 2>&1 &
echo $! > "$SANDBOX/.heavy.pid"
