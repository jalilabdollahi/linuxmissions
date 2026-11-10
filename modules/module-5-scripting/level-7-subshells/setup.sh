#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/task-a.sh" <<'SCRIPT'
#!/bin/bash
# rotate the application logs
echo "[a] rotating logs"
sleep 2
echo "logs rotated" > a.out
echo "[a] done"
SCRIPT

cat > "$SANDBOX/task-b.sh" <<'SCRIPT'
#!/bin/bash
# back up the database
echo "[b] dumping database"
sleep 2
echo "[b] backup failed: disk quota exceeded on /backups" >&2
exit 1
SCRIPT

cat > "$SANDBOX/task-c.sh" <<'SCRIPT'
#!/bin/bash
# warm the cache for the morning traffic
echo "[c] warming cache"
sleep 2
echo "cache warmed" > c.out
echo "[c] done"
SCRIPT

cat > "$SANDBOX/run_all.sh" <<'SCRIPT'
#!/bin/bash
# run_all.sh - start the three maintenance tasks in parallel,
# wait for all of them, exit 1 if any failed.
# TODO
SCRIPT

chmod +x "$SANDBOX"/task-a.sh "$SANDBOX"/task-b.sh "$SANDBOX"/task-c.sh "$SANDBOX"/run_all.sh
