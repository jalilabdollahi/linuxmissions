#!/bin/bash
# What Changed Last Night: ~35 configs with mtimes set relative to now.
# Five changed 2-21 h ago (the answer, partly random which ones); three changed
# 26-40 h ago (what `-mtime 1` lists); the rest days or months ago. One old file
# was just read (fresh atime), every file has a fresh ctime (setup created it),
# and etc/nginx/conf.d itself is a recently modified directory.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
NOW=$(date +%s)

ago() {  # ago HOURS FILE...  set mtime (and atime) to HOURS hours before now
  local t=$(( NOW - $1 * 3600 - 300 )) stamp
  shift
  stamp=$(date -d "@$t" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$t" +%Y%m%d%H%M.%S)
  touch -t "$stamp" "$@"
}

files="etc/hostname etc/hosts etc/resolv.conf etc/fstab etc/environment etc/timezone
etc/ntp.conf etc/default/grub etc/ssh/sshd_config etc/ssh/ssh_config
etc/nginx/nginx.conf etc/nginx/mime.types etc/nginx/sites-enabled/shop.conf
etc/nginx/sites-enabled/admin.conf etc/haproxy/haproxy.cfg etc/sysctl.d/99-tuning.conf
etc/security/limits.conf etc/cron.d/backup etc/cron.d/reports etc/logrotate.d/shop
etc/postgresql/16/main/postgresql.conf etc/postgresql/16/main/pg_hba.conf
etc/redis/redis.conf etc/shop/app.yaml etc/shop/features.yaml etc/shop/secrets.env
etc/shop/workers.yaml etc/systemd/system/shop-api.service etc/systemd/system/shop-worker.service
etc/systemd/system/shop-worker.timer etc/sudoers.d/deploy etc/docker/daemon.json
etc/rsyslog.d/50-default.conf etc/profile.d/proxy.sh"
for f in $files; do
  mkdir -p "$(dirname "$f")"
  printf '# %s\n# managed by ansible\nsetting_%d = %d\n' "$f" $RANDOM $RANDOM > "$f"
done
mkdir -p etc/nginx/conf.d
printf 'limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;\n' > etc/nginx/conf.d/rate-limit.conf

# Shuffle the files; the first entries get the interesting ages.
shuffled=$(printf '%s\n' $files | awk -v seed="$RANDOM" 'BEGIN { srand(seed) } { print rand() "\t" $0 }' | sort -n | cut -f2)
set -- $shuffled
: > .lm-state/ages
age() { ago "$1" "$2"; printf '%s %s\n' "$2" "$1" >> .lm-state/ages; }
age 2 etc/nginx/conf.d/rate-limit.conf
age 7 "$1"; age 14 "$2"; age 20 "$3"; age 21 "$4"       # changed in the last 24 h
age 26 "$5"; age 33 "$6"; age 40 "$7"                     # 1-2 days ago
age 75 "$8"; age 216 "$9"                                 # 3 and 9 days ago
shift 9
for f in "$@"; do age $(( 24 * (15 + RANDOM % 400) )) "$f"; done

# An old file someone just read: fresh access time, old modification time.
reader=$(awk '$2 > 300 { print $1; exit }' .lm-state/ages)
touch -a "$reader"

# Directories: old, except conf.d, which got a new file two hours ago.
find etc -type d -exec touch -t 202607010900 {} +
ago 2 etc/nginx/conf.d
touch -a etc/nginx/conf.d

awk '$2 < 24 { print $1 }' .lm-state/ages | LC_ALL=C sort > .lm-state/recent
