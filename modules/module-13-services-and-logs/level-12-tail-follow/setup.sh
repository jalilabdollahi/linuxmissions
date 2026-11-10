#!/bin/bash
# A deploy agent (background process) writes var/log/deploy/deploy.log by
# name (>> on every line). When ./trigger-deploy.sh asks for a deploy, it
# logs a few steps, rotates its log (deploy.log -> deploy.log.1, new
# deploy.log), prints a one-time admin token into the NEW file, and about
# ten seconds later scrubs it (truncates deploy.log). The token is never in
# deploy.log.1. trigger-deploy.sh only returns after the scrub, so the only
# way to see the token is to follow the log by name (tail -F) from before
# the trigger. `tail -f` follows the renamed file and never sees it.
# While idle, the agent's housekeeping logs revoked old tokens: a tail that
# prints the last 10 lines and takes the first token it sees gets one of those.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/deploy-agent var/log/deploy run .lm-state

cat > opt/deploy-agent/deploy-agent <<'EOF'
#!/bin/bash
# deploy-agent: waits for run/deploy.request, deploys, logs to var/log/deploy/deploy.log
cd "$1" || exit 1
LOG=var/log/deploy/deploy.log
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [deploy-agent] $*" >> "$LOG"; }
tok() { echo "adm_$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)"; }
sha() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }
revoke() {
  local t; t=$(tok)
  sha "$t" >> .lm-state/revoked.sha
  log "housekeeping: revoked unused admin token $t from deploy 2026.11.0$((1 + RANDOM % 9))-$((1 + RANDOM % 4))"
}
n=0
while :; do
  if [ -e run/deploy.request ]; then
    rm -f run/deploy.request run/deploy.done
    rel="2026.11.10-$((RANDOM % 90 + 10))"
    log "deploy $rel requested by $(cat run/deploy.who 2>/dev/null || echo operator)"
    sleep 1; log "deploy $rel: pulling image registry.internal/shop/api:$rel"
    sleep 1; log "deploy $rel: running migrations (3 pending)"
    sleep 1; log "deploy $rel: migrations done, rotating deploy log"
    [ -e "$LOG.1" ] && mv "$LOG.1" "$LOG.2"
    mv "$LOG" "$LOG.1"
    : > "$LOG"
    t=$(tok)
    sha "$t" >> .lm-state/issued.sha
    log "deploy $rel: switching traffic to the new release"
    log "deploy $rel: one-time admin token: $t (valid 15 min, printed once)"
    for s in "warming caches" "health checks passing (3/3)" "old release drained" "smoke tests passed"; do
      sleep 2.5; log "deploy $rel: $s"
    done
    : > "$LOG"
    log "deploy $rel: log scrubbed of secrets"
    log "deploy $rel: finished"
    touch run/deploy.done
  fi
  n=$((n + 1))
  [ $((n % 20)) -eq 0 ] && log "agent idle, waiting for deploy requests"
  [ $((n % 45)) -eq 0 ] && revoke
  sleep 0.5
done
EOF
chmod +x opt/deploy-agent/deploy-agent

cat > trigger-deploy.sh <<'EOF'
#!/bin/bash
# Ask the deploy agent for a deploy and wait until it has finished.
cd "$(dirname "$0")" || exit 1
rm -f run/deploy.done
echo "${USER:-operator}" > run/deploy.who
touch run/deploy.request
echo "deploy requested, waiting for the agent..."
for _ in $(seq 1 120); do
  if [ -e run/deploy.done ]; then
    echo "deploy finished. (the admin token was printed in var/log/deploy/deploy.log, once)"
    exit 0
  fi
  sleep 0.5
done
echo "the deploy agent did not answer within 60s" >&2
exit 1
EOF
chmod +x trigger-deploy.sh

# Yesterday's history, ending with housekeeping lines.
{
  for h in 08 09 10 11 12 13 14 15 16 17 18; do
    echo "2026-11-09 $h:00:0$((RANDOM % 10)) [deploy-agent] agent idle, waiting for deploy requests"
  done
  echo "2026-11-09 18:12:44 [deploy-agent] deploy 2026.11.09-4 requested by mkoster"
  echo "2026-11-09 18:13:10 [deploy-agent] deploy 2026.11.09-4: log scrubbed of secrets"
  echo "2026-11-09 18:13:10 [deploy-agent] deploy 2026.11.09-4: finished"
} > var/log/deploy/deploy.log
for _ in 1 2; do
  t="adm_$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)"
  printf '%s' "$t" | sha256sum | cut -d' ' -f1 >> .lm-state/revoked.sha
  echo "$(date '+%Y-%m-%d %H:%M:%S') [deploy-agent] housekeeping: revoked unused admin token $t from deploy 2026.11.09-$((RANDOM % 3 + 1))" >> var/log/deploy/deploy.log
done
echo "$(date '+%Y-%m-%d %H:%M:%S') [deploy-agent] agent idle, waiting for deploy requests" >> var/log/deploy/deploy.log
touch .lm-state/issued.sha

nohup bash "$SANDBOX/opt/deploy-agent/deploy-agent" "$SANDBOX" >/dev/null 2>&1 &
exit 0
