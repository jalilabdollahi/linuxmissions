#!/bin/bash
SANDBOX="$1"

# The runaway: mostly busy, with tiny pauses; gives up on its own after an hour.
cat > "$SANDBOX/report_builder.sh" <<'SCRIPT'
#!/bin/bash
while [ "$SECONDS" -lt 3600 ]; do
  i=0
  while [ "$i" -lt 200000 ]; do i=$((i + 1)); done
  sleep 0.1
done
SCRIPT

# Two well-behaved jobs that mostly sleep.
cat > "$SANDBOX/queue_worker.sh" <<'SCRIPT'
#!/bin/bash
while [ "$SECONDS" -lt 3600 ]; do sleep 5; done
SCRIPT
cp "$SANDBOX/queue_worker.sh" "$SANDBOX/log_shipper.sh"
chmod +x "$SANDBOX"/*.sh

bash "$SANDBOX/queue_worker.sh"   >/dev/null 2>&1 &
bash "$SANDBOX/report_builder.sh" >/dev/null 2>&1 &
echo $! > "$SANDBOX/.culprit.pid"
bash "$SANDBOX/log_shipper.sh"    >/dev/null 2>&1 &
