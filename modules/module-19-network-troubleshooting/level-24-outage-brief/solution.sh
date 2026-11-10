#!/bin/bash
# Work through smoke.sh's failures one by one, then fill in the brief.
PATH="$PWD/bin:$PATH"
dns=$(grep -o 'port [0-9]*' TICKET.txt | head -1 | cut -d' ' -f2)
./smoke.sh
# 1. corp hosts must not go through the proxy
sed -i.bak 's/^export no_proxy=.*/export no_proxy=localhost,127.0.0.1,.corp.example/' checkout/client.env
# 2. the port moved: DNS publishes it as SRV
port=$(dig @127.0.0.1 -p "$dns" _payments._tcp.corp.example SRV +short | awk '{ print $3 }' | head -1)
sed -i "s/^PAYMENTS_PORT=.*/PAYMENTS_PORT=$port/" checkout/client.env
./smoke.sh
# 3. a stale etc/hosts pin: compare with DNS
for b in pay-1 pay-2 pay-3; do
  echo "$b $(getent hosts $b.corp.example | awk '{print $1}') $(dig @127.0.0.1 -p "$dns" $b.corp.example +short)"
done
stale=$(for b in pay-1 pay-2 pay-3; do
  [ "$(getent hosts $b.corp.example | awk '{print $1}')" != "$(dig @127.0.0.1 -p "$dns" $b.corp.example +short)" ] && echo $b
done)
sed -i.bak "/[[:space:]]$stale\.corp\.example/d" etc/hosts
# 4. the backend that answers 503
sick=$(./smoke.sh | awk '/FAIL/ && /HTTP 503/ { split($2, a, ":"); print a[1] }')
sed -i "s/ *$sick//; s/\"$sick */\"/" checkout/client.env
./smoke.sh
fails=$(grep 'ERROR payments call failed' logs/checkout.log)
cat > brief.md <<EOT
# Outage brief: checkout -> payments (INC-4410)

impact_start: $(echo "$fails" | head -1 | cut -d' ' -f1)
impact_end: $(echo "$fails" | tail -1 | cut -d' ' -f1)
failed_calls: $(echo "$fails" | wc -l)
new_port: $port
removed_backend: $sick
root_cause: CHG-7001 moved the payments listeners to port $port but checkout's client.env still used 8080; CHG-7002 and CHG-7005 then added a stale hosts pin and proxied corp traffic
fix: no_proxy gets .corp.example, PAYMENTS_PORT=$port, removed the stale $stale pin from etc/hosts, took $sick (503) out of PAYMENTS_BACKENDS
EOT
cat brief.md
