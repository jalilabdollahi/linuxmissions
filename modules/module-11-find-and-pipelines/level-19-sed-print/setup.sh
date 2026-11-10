#!/bin/bash
# Vendor Ticket: an INI file whose [database] section sits after a
# [database-replica] section (which even mentions "[database]" in a comment),
# and a 40,000-line trace log. Values and log content change on every setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

r() { echo $(( RANDOM % $1 + ${2:-0} )); }
cat > app.ini <<INI
; app.ini for orders-api, managed by config management
; local changes are overwritten on the next run

[server]
listen = 0.0.0.0:$(r 1000 8000)
workers = $(r 12 4)
request_timeout = $(r 50 10)s
trusted_proxies = 10.0.0.0/8

[database-replica]
; read-only copy of [database], used by the reporting jobs
host = db-replica-$(r 3 1).orders.internal
port = 5432
name = orders
user = orders_reports
pool_size = $(r 8 2)

[database]
host = db-primary.orders.internal
port = $(r 2 5432)
name = orders
user = orders_app
password_file = /etc/orders-api/db.secret
pool_size = $(r 40 10)
; timeouts in seconds
connect_timeout = $(r 9 2)
statement_timeout = $(r 50 10)
sslmode = verify-full

[cache]
backend = redis
url = redis://cache.orders.internal:6379/$(r 4)
ttl = $(r 600 60)

[logging]
level = info
file = /var/log/orders-api/trace.log
INI

awk -v seed="$RANDOM$$" 'BEGIN {
  srand(seed)
  split("INFO INFO INFO INFO DEBUG DEBUG WARN ERROR", lvl, " ")
  split("http-nio-8080-exec-1 http-nio-8080-exec-2 http-nio-8080-exec-7 scheduling-1 HikariPool-1 main", thr, " ")
  split("OrderController OrderService PaymentClient InventoryClient OrderRepository HikariPool", cls, " ")
  split("Handling GET /orders/%d|Handling POST /orders|Fetched order %d|Payment authorised for order %d|Connection added (total=%d)|Reserved stock for order %d|Slow query: %d ms|Retrying request %d", msg, "|")
  t = 36000; n = 0
  while (n < 40000) {
    t += rand() * 0.8
    printf "2026-11-09 %02d:%02d:%06.3f %-5s [%s] c.e.orders.%s - ", int(t / 3600), int(t / 60) % 60, t % 60, lvl[int(rand() * 8) + 1], thr[int(rand() * 6) + 1], cls[int(rand() * 6) + 1]
    m = int(rand() * 8) + 1
    v = (m == 5) ? int(rand() * 10) + 1 : (m == 7) ? int(rand() * 9000) + 1000 : int(rand() * 900000) + 1000
    printf msg[m] "\n", v
    n++
    # the exception the vendor asked about starts around line 1225
    if (rand() < 0.01 || (n >= 1222 && !forced && forced = 1)) {
      print "org.postgresql.util.PSQLException: ERROR: canceling statement due to statement timeout"
      k = 3 + int(rand() * 6)
      for (i = 0; i < k; i++) printf "\tat c.e.orders.%s.method%d(%s.java:%d)\n", cls[int(rand() * 6) + 1], i, cls[int(rand() * 6) + 1], int(rand() * 400) + 20
      n += k + 1
    }
  }
}' > trace.log

cat app.ini trace.log | cksum > .lm-state/inputs.sum
