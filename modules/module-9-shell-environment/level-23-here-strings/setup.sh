#!/bin/bash
# DSN Splitter: parse-dsn.sh pipes into `read`, so every variable is set in a
# subshell and lost; it also splits at the FIRST @ (passwords may contain @ and
# :) and writes values unquoted, so `source db.env` breaks on $ and spaces.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > parse-dsn.sh <<'EOF'
#!/bin/bash
# parse-dsn.sh DSN - split a database URL into db.env for the app.
#   scheme://user:password@host[:port]/dbname       (port defaults to 5432)
# Writes db.env (DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME) into the current
# directory; the app loads it with `source db.env`.
dsn="$1"
rest="${dsn#*://}"                     # user:password@host:port/dbname

echo "$rest" | IFS=@ read -r creds hostpart
echo "$creds" | IFS=: read -r DB_USER DB_PASS
echo "$hostpart" | IFS=/ read -r hostport DB_NAME
echo "$hostport" | IFS=: read -r DB_HOST DB_PORT

cat > db.env <<END
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
END
EOF
chmod +x parse-dsn.sh

pw="$(printf '%04x' $RANDOM)@$(printf '%03d' $(( RANDOM % 1000 )))"
cat > dsns.txt <<EOF
# DSNs from the secrets vault, to try parse-dsn.sh with
postgres://app:p@ss@db-2:5432/orders
postgres://report:s3:cr3t@analytics.internal/warehouse
mysql://root:pa\$\$w0rd!@10.0.0.5:3306/shop
postgres://billing:$pw@pg-billing.prod:6432/billing_$(( RANDOM % 90 + 10 ))
EOF
