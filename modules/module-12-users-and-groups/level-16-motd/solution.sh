#!/bin/bash
chmod -x etc/update-motd.d/20-maintenance
cat > etc/update-motd.d/50-disk <<'LMEND'
#!/bin/sh
printf 'Disk usage (/): %s\n' "$(df -P / | awk 'NR == 2 { print $5 }')"
LMEND
chmod +x etc/update-motd.d/50-disk
bin/render-motd
