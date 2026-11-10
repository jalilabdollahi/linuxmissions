#!/bin/bash
# Survive the Hangup: run migrate.sh so that it ignores SIGHUP and logs to
# logs/migrate.log. The script re-executes itself by its absolute path so the
# sandbox path is in its command line (the engine stops it on reset).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p logs

cat > migrate.sh <<'SH'
#!/bin/bash
# Copy the orders table to the new cluster: 14400 batches, about one per second.
case "$0" in
  /*) ;;
  *) exec "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" "$@" ;;
esac
total=14400
echo "$(date '+%F %T') migration started (pid $$), $total batches to go"
i=0
while [ "$i" -lt "$total" ]; do
  i=$((i + 1))
  sleep 1
  echo "$(date '+%F %T') batch $i/$total: 500 rows copied"
  if [ $((i % 45)) -eq 0 ]; then
    echo "$(date '+%F %T') warning: batch $i: 2 rows had invalid UTF-8, stored as-is" >&2
  fi
done
echo "$(date '+%F %T') migration finished"
SH
chmod 755 migrate.sh

cat > logs/migrate-dryrun.log <<'LOG'
2025-11-03 18:02:11 migration started (pid 48213), 14400 batches to go
2025-11-03 18:02:12 batch 1/14400: 500 rows copied
2025-11-03 18:02:13 batch 2/14400: 500 rows copied
2025-11-03 18:02:14 batch 3/14400: 500 rows copied
(dry run stopped by hand)
LOG
