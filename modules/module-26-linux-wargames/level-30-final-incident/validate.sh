#!/bin/bash
SB="$1"; cd "$SB" || exit 1
export LM_ROOT="$SB"
SC="$SB/bin/systemctl"
PORT=$(cat .lm/port)
used() { find var/cache/shop var/spool/shop var/log/shop -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END{print s+0}'; }
health() { curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$PORT/health" 2>/dev/null; }

if [ "$("$SC" is-active shop 2>/dev/null)" != "active" ]; then echo "❌ the shop service is not running (systemctl status shop, journalctl -u shop)"; exit 1; fi
if [ "$(health)" != "200" ]; then echo "❌ shop is active but /health on port $PORT does not answer 200"; exit 1; fi

ut=$("$SB/bin/crontab" -l 2>/dev/null)
if grep -q cache-warm <<<"$ut" || grep -rqs cache-warm etc/cron.d etc/crontab; then
  echo "❌ the runaway job is still scheduled: cron reads more than one place"; exit 1; fi
if ! grep -q nightly-backup <<<"$ut" || ! grep -q heartbeat <<<"$ut"; then
  echo "❌ a legitimate cron job (nightly-backup or heartbeat) was removed along with the bad one"; exit 1; fi

u1=$(used); sleep 5; u2=$(used)
if [ $((u2 - u1)) -gt 102400 ]; then echo "❌ disk usage is still growing: something is still writing into the volume"; exit 1; fi
limit=$(( $(cat etc/shop/disk.limit) * 1024 * 1024 ))
if [ "$u2" -gt $((limit / 2)) ]; then echo "❌ the volume holds $((u2 >> 20)) MB, above half of the $((limit >> 20)) MB limit: RETENTION.md allows more cleanup than the cache"; exit 1; fi
if ! sha256sum -c --quiet .lm/audit.sha >/dev/null 2>&1; then echo "❌ audit/deploy evidence under var/cache/shop/audit was deleted or changed"; exit 1; fi
for f in var/spool/shop/orders-2026-11-08.jsonl var/spool/shop/orders-2026-11-10.jsonl var/log/shop/shop.log var/log/cron.log; do
  [ -e "$f" ] || { echo "❌ $f is within retention and must be kept"; exit 1; }; done

body=$(cat .lm/leaked.body)
if [ -e etc/shop/deploy_key ] || grep -rqsF "$body" etc home opt var; then echo "❌ the leaked deploy key is still somewhere (authorized_keys files, deploy config, or the key files themselves)"; exit 1; fi
while read -r b; do
  grep -rqsF "$b" etc home || { echo "❌ a legitimate key was removed along with the leaked one"; exit 1; }
done < .lm/legit.bodies

if [ "$("$SC" is-active shop 2>/dev/null)" != "active" ] || [ "$(health)" != "200" ]; then echo "❌ the shop went down again after the fixes"; exit 1; fi
[ -s postmortem.json ] && jq -e . postmortem.json >/dev/null 2>&1 || { echo "❌ postmortem.json is missing or not valid JSON"; exit 1; }
if [ "$(jq -cS 'keys' postmortem.json)" != '["cause_chain","deploy_id","first_bad_cron_run","key_fingerprint"]' ]; then echo "❌ postmortem.json needs exactly cause_chain, deploy_id, first_bad_cron_run, key_fingerprint"; exit 1; fi
[ "$(jq -r .first_bad_cron_run postmortem.json)" = "$(cat .lm/first_run)" ] || { echo "❌ first_bad_cron_run is wrong (first run of the runaway job in the cron log, format YYYY-MM-DD HH:MM)"; exit 1; }
[ "$(jq -r .key_fingerprint postmortem.json)" = "$(cat .lm/fp)" ] || { echo "❌ key_fingerprint is not the fingerprint of the leaked key"; exit 1; }
[ "$(jq -r .deploy_id postmortem.json)" = "$(cat .lm/deploy_id)" ] || { echo "❌ deploy_id is not the deploy that used the leaked key"; exit 1; }
[ "$(jq -c .cause_chain postmortem.json)" = '["leaked-key","bad-deploy","cron-every-minute","disk-full","app-down"]' ] || { echo "❌ cause_chain is not the real chain, root cause first"; exit 1; }
echo "✅ shop healthy, runaway cron gone from every place, disk cleaned per retention with evidence kept, key revoked, postmortem exact"
