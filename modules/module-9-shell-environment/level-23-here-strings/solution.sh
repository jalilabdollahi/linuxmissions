#!/bin/bash
# Split at the LAST @ with parameter expansion, read with here-strings (no
# subshell), default the port, and quote every value for `source`.
cat > parse-dsn.sh <<'EOF'
#!/bin/bash
# parse-dsn.sh DSN - split a database URL into db.env for the app.
#   scheme://user:password@host[:port]/dbname       (port defaults to 5432)
dsn="$1"
rest="${dsn#*://}"                     # user:password@host:port/dbname
creds="${rest%@*}"                     # before the LAST @ (the password may contain @)
hostpart="${rest##*@}"                 # after the last @

IFS=: read -r DB_USER DB_PASS <<< "$creds"
IFS=/ read -r hostport DB_NAME <<< "$hostpart"
IFS=: read -r DB_HOST DB_PORT <<< "$hostport"
DB_PORT="${DB_PORT:-5432}"

printf 'DB_USER=%q\nDB_PASS=%q\nDB_HOST=%q\nDB_PORT=%q\nDB_NAME=%q\n' \
  "$DB_USER" "$DB_PASS" "$DB_HOST" "$DB_PORT" "$DB_NAME" > db.env
EOF
./parse-dsn.sh 'postgres://report:s3:cr3t@analytics.internal/warehouse'
cat db.env
