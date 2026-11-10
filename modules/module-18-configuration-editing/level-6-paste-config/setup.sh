#!/bin/bash
# One Line for the Balancer: hosts.txt and ports.txt are parallel lists. ports.txt
# ends with an extra blank line (an old editor), which would make paste emit a
# dangling ":" entry. The number of backends changes on every run.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

n=$((5 + RANDOM % 4))
: > hosts.txt
: > ports.txt
base=8000
for i in $(seq 1 "$n"); do
  echo "web$i" >> hosts.txt
  echo "$((base + i))" >> ports.txt
done
echo >> ports.txt

cat > lb.env <<'CONF'
# lb.env - load balancer settings
LB_BIND=0.0.0.0:443
LB_ALGORITHM=leastconn
HEALTH_INTERVAL=5s
CONF
cp lb.env .lm-state/lb.env.orig

line="BACKENDS="
for i in $(seq 1 "$n"); do
  line="$line$([ "$i" -gt 1 ] && echo ,)web$i:$((base + i))"
done
echo "$line" > .lm-state/want-line
