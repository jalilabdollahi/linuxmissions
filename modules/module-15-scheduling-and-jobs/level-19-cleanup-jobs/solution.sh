#!/bin/bash
cat > cleanup.sh <<'EOF'
#!/bin/bash
# cleanup.sh - nightly cache cleanup for the shop app (cron, 03:15).
# Removes cache files that have not changed for more than a week.
# CACHE_DIR comes from the crontab (see crontab.txt).
set -u
: "${CACHE_DIR:?CACHE_DIR is not set}"
[ -d "$CACHE_DIR" ] || { echo "cleanup.sh: $CACHE_DIR is not a directory" >&2; exit 1; }
find "$CACHE_DIR" -mindepth 1 -type f -mtime +7 ! -name .keep -delete
EOF
