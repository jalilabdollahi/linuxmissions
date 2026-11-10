#!/bin/bash
SANDBOX="$1"

# The buggy parent: forks 3 workers that exit at once, and never wait()s for them.
cat > "$SANDBOX/job_runner.py" <<SCRIPT
#!/usr/bin/env python3
import os, time

children = []
for _ in range(3):
    pid = os.fork()
    if pid == 0:
        os._exit(0)          # worker finishes immediately
    children.append(pid)

with open("$SANDBOX/.zombies.expected", "w") as f:
    f.write("\n".join(map(str, children)) + "\n")
time.sleep(3600)             # BUG: never calls os.wait()
SCRIPT

# A healthy neighbour that must survive
cat > "$SANDBOX/metrics_agent.py" <<'SCRIPT'
#!/usr/bin/env python3
import time
for _ in range(720):
    time.sleep(5)
SCRIPT
chmod +x "$SANDBOX/job_runner.py" "$SANDBOX/metrics_agent.py"

python3 "$SANDBOX/metrics_agent.py" >/dev/null 2>&1 &
echo $! > "$SANDBOX/.agent.pid"
python3 "$SANDBOX/job_runner.py" >/dev/null 2>&1 &
echo $! > "$SANDBOX/.parent.pid"

# Wait until the zombies exist so the level is ready when the prompt appears
for _ in $(seq 50); do
  [ -s "$SANDBOX/.zombies.expected" ] && break
  sleep 0.1
done
