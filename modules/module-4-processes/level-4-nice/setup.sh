#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/heavy.sh" <<'SCRIPT'
#!/bin/bash
while true; do :; done
SCRIPT

chmod +x "$SANDBOX/heavy.sh"

cat > "$SANDBOX/README" <<'README'
Start heavy.sh with a lower priority.
Save the background PID to pid.txt.
Use ps to verify the NI column.
README
