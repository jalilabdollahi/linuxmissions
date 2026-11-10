#!/bin/bash
# Drain Rack B: whitespace-aligned table, columns name(12) host(16) port(6) weight(8) rack.
# Comments contain the letter B, one hostname starts with "b", and the weights have
# different widths, so $4=0 (which rebuilds the line with single spaces) is wrong.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

cat > upstreams.tab <<'EOF2'
# upstreams.tab - backends of the public load balancer
# name         host            port  weight  rack
# rack B is on the old UPS and is being drained on Friday (B-side switch)

web-a1       10.1.1.11       8080  100     A
web-a2       10.1.1.12       8080  100     A
web-b1       10.2.1.11       8080  100     B
web-b2       10.2.1.12       8080  50      B
api-a1       10.1.2.21       9000  25      A
api-b1       10.2.2.21       9000  25      B

# batch workers
bq-worker-1  10.3.1.31       5672  10      C
bq-worker-2  10.2.3.32       5672  5       B
cache-b      10.1.3.40       6379  100     A
cache-c      10.3.3.41       6379  100     C
EOF2

# Expected: weight of rack-B rows becomes "0" padded to the column width.
awk '$0 !~ /^#/ && NF == 5 && $5 == "B" {
       printf "%-12s %-15s %-5s %-7s %s\n", $1, $2, $3, "0", $5; next }
     { print }' upstreams.tab > .lm-state/expected.tab
cp upstreams.tab .lm-state/original.tab
