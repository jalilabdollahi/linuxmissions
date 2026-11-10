#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

ts() { printf '2024-03-14T%02d:%02d:%02d' $(( $1 / 3600 % 24 )) $(( $1 / 60 % 60 )) $(( $1 % 60 )); }

{
  echo "$(ts 7200) INFO  [main] payment-service 3.8.1 starting (pid 4121)"
  echo "$(ts 7201) INFO  [main] loaded config from /etc/payments/app.conf"
  echo "$(ts 7202) INFO  [db] connected to db-primary.internal:5432 (pool=20)"
  echo "$(ts 7202) WARN  [main] TLS certificate expires in 12 days"
  echo "$(ts 7203) INFO  [http] listening on :8443"
  for i in $(seq 1 2989); do
    t=$(( 7203 + i * 9 ))
    case $(( i % 97 )) in
      0)  echo "$(ts $t) WARN  [worker-$(( i % 8 ))] slow query on orders: $(( 800 + i % 400 ))ms" ;;
      13) echo "$(ts $t) INFO  [http] GET /health 200 1ms" ;;
      *)  echo "$(ts $t) INFO  [worker-$(( i % 8 ))] payment id=$(( 100000 + i * 37 )) captured in $(( 20 + i % 180 ))ms" ;;
    esac
  done
  echo "$(ts 34110) ERROR [db] connection reset by peer"
  echo "$(ts 34111) ERROR [worker-3] payment id=210644 failed: no database connection"
  echo "$(ts 34112) ERROR [db] reconnect failed after 5 attempts"
  echo "$(ts 34112) FATAL [main] too many errors, shutting down"
  echo "$(ts 34113) INFO  [main] payment-service stopped (exit code 1)"
  echo "$(ts 34113) INFO  [main] goodbye"
} > app.log
