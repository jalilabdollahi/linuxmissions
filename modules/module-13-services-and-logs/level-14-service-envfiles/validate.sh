#!/bin/bash
# billing must run with the ticket's DB_HOST/DB_PORT, the values must be in
# /etc/billing/env, that file must be one systemd really loads for the unit,
# and the vendor binary must be unchanged. The running environment is what
# the mock recorded when it started the service (LMEnvironment).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
read -r HOST PORT < .lm-state/want 2>/dev/null
SC=bin/systemctl

if [ -z "$HOST" ]; then
  echo "❌ the level's data in .lm-state is gone; type 'reset'"
  exit 1
fi
if [ "$(cksum < opt/billing/bin/billing-server 2>/dev/null)" != "$(cat .lm-state/binary.sum)" ]; then
  echo "❌ the vendor binary opt/billing/bin/billing-server was changed; type 'reset' and fix the configuration instead"
  exit 1
fi

state=$($SC is-active billing.service 2>/dev/null)
if [ "$state" != active ]; then
  echo "❌ billing.service is $state; systemctl status billing and its journal say why"
  exit 1
fi
envline=$(grep '^LMEnvironment=' .lm/systemd/units/billing.service.state 2>/dev/null)
run_host=$(printf '%s' "$envline" | grep -o '"DB_HOST=[^"]*"' | tr -d '"' | cut -d= -f2-)
run_port=$(printf '%s' "$envline" | grep -o '"DB_PORT=[^"]*"' | tr -d '"' | cut -d= -f2-)
if [ "$run_host" != "$HOST" ] || [ "$run_port" != "$PORT" ]; then
  echo "❌ the running billing uses $run_host:$run_port, not the new primary from the ticket"
  exit 1
fi

# /etc/billing/env, read the way systemd reads it (no inline comments).
envfile_val() {
  tr -d '\r' < etc/billing/env 2>/dev/null | sed -n "s/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}$1[[:space:]]*=[[:space:]]*//p" \
    | tail -1 | sed 's/[[:space:]]*$//; s/^"\(.*\)"$/\1/; s/^'"'"'\(.*\)'"'"'$/\1/'
}
if [ "$(envfile_val DB_HOST)" != "$HOST" ] || [ "$(envfile_val DB_PORT)" != "$PORT" ]; then
  echo "❌ billing has the right values, but etc/billing/env must hold them (DB_HOST=$HOST, DB_PORT=$PORT): config management owns that file"
  exit 1
fi
if ! $SC show -P EnvironmentFiles billing.service 2>/dev/null | grep -q '^/etc/billing/env '; then
  echo "❌ billing has the right values, but not from /etc/billing/env: the unit (as systemd has it loaded) doesn't read that file"
  exit 1
fi

echo "✅ billing runs against $HOST:$PORT, loaded from /etc/billing/env"
exit 0
