#!/bin/bash
# Pretty Table: a CSV service inventory whose last column contains spaces,
# so splitting on whitespace breaks it; it must be split on commas.
SANDBOX="$1"

cat > "$SANDBOX/services.csv" <<'EOF'
service,owner,status,port,description
api,payments,healthy,8080,Public REST API
worker,payments,degraded,9090,Background job runner
cache,platform,healthy,6379,Redis session cache
auth,identity,healthy,8443,Login and token service
search,discovery,healthy,9200,Product search index
mailer,growth,down,2525,Transactional e-mail sender
billing,payments,healthy,8081,Invoices and refunds
gateway,platform,healthy,443,Edge proxy and TLS termination
reports,finance,degraded,8090,Nightly PDF reports
metrics,platform,healthy,9100,Prometheus exporter
scheduler,platform,healthy,8070,Cron replacement for jobs
geoip,discovery,healthy,8085,IP to country lookup
ledger,finance,healthy,5433,Double-entry bookkeeping DB
chat-bot,support,down,3000,Customer support assistant
EOF
