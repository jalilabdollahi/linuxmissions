#!/bin/bash
# Tune the Database Section: my.cnf with [client], [mysqld], [mysqldump] and a second
# [mysqld] block at the end. max_allowed_packet exists in three sections, a comment
# mentions max_connections, and the second block has its own settings.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

cat > my.cnf <<'CONF'
# my.cnf - db-02, managed by hand since the migration
[client]
port = 3306
socket = /var/run/mysqld/mysqld.sock
max_allowed_packet = 16M

[mysqld]
# max_connections = 1000 was tried in 2022 and ran out of RAM
user = mysql
datadir = /var/lib/mysql
max_connections = 151
max_allowed_packet = 64M
skip-name-resolve

[mysqldump]
quick
max_allowed_packet = 128M

# slow query logging, added by the performance team
[mysqld]
slow_query_log = 1
long_query_time = 2
CONF
cp my.cnf .lm-state/original.cnf
