#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/make_zombies.py" <<SCRIPT
#!/usr/bin/env python3
import os
import time
from pathlib import Path

for _ in range(3):
    pid = os.fork()
    if pid == 0:
        os._exit(0)

Path("$SANDBOX/parent.pid").write_text(str(os.getpid()), encoding="utf-8")
time.sleep(3600)
SCRIPT

chmod +x "$SANDBOX/make_zombies.py"
setsid python3 "$SANDBOX/make_zombies.py" >/dev/null 2>&1 &
