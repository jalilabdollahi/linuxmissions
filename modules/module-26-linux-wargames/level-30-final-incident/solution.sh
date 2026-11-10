#!/bin/bash
export PATH="$PWD/bin:$PATH"
crontab -l
cat etc/cron.d/warmup
crontab -l | grep -v cache-warm | crontab -
rm etc/cron.d/warmup
find var/cache/shop -maxdepth 1 -name 'warm-*.bin' -delete
find var/spool/shop -name 'orders-*.jsonl' -mtime +3 -delete
fp=$(ssh-keygen -lf etc/shop/deploy_key.pub | awk '{print $2}')
body=$(awk '{print $2}' etc/shop/deploy_key.pub)
id=$(grep -l "$fp" var/cache/shop/audit/*.log | sed 's|.*/deploy-||; s|\.log$||')
first=$(grep cache-warm var/log/cron.log | head -1 | awk '{print $1, $2, "2026", $3}')
first=$(date -d "$first" '+%F %H:%M')
for f in home/deploy/.ssh/authorized_keys home/ci/.ssh/authorized_keys etc/shop/deploy.conf; do grep -vF "$body" "$f" > "$f.new" && mv "$f.new" "$f"; done
rm etc/shop/deploy_key etc/shop/deploy_key.pub
systemctl restart shop
jq -n --arg t "$first" --arg fp "$fp" --arg id "$id" '{first_bad_cron_run:$t, key_fingerprint:$fp, deploy_id:$id, cause_chain:["leaked-key","bad-deploy","cron-every-minute","disk-full","app-down"]}' > postmortem.json
