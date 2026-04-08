#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/task-a.sh" <<'SCRIPT'
#!/bin/bash
sleep 1
echo "A done" > a.out
SCRIPT

cat > "$SANDBOX/task-b.sh" <<'SCRIPT'
#!/bin/bash
sleep 1
echo "B done" > b.out
SCRIPT

cat > "$SANDBOX/task-c.sh" <<'SCRIPT'
#!/bin/bash
sleep 1
echo "C done" > c.out
SCRIPT

cat > "$SANDBOX/run_all.sh" <<'SCRIPT'
#!/bin/bash
# TODO: run all task scripts in parallel and wait for them
SCRIPT

chmod +x "$SANDBOX"/task-a.sh "$SANDBOX"/task-b.sh "$SANDBOX"/task-c.sh "$SANDBOX"/run_all.sh
