#!/bin/bash
# Scheduled Sweep: add a weekday 03:00 job for cleanup.sh to an existing
# crontab file without breaking the jobs already in it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > cleanup.sh <<'EOF'
#!/bin/bash
# Deletes upload temp files older than 2 days.
find /var/tmp/myapp-uploads -type f -mtime +2 -delete 2>/dev/null
echo "$(date '+%F %T') cleanup done"
EOF
chmod +x cleanup.sh

cat > crontab.txt <<'EOF'
# crontab for user deploy -- installed with: crontab crontab.txt
#
# m   h   dom mon dow   command
MAILTO=ops@example.com
PATH=/usr/local/bin:/usr/bin:/bin

*/15  *   *   *   *     /opt/myapp/bin/healthcheck >/dev/null 2>&1
30    2   *   *   0     /usr/local/bin/backup.sh --weekly
EOF
