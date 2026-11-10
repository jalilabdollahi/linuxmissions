#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

ts() { printf '2024-03-14 %02d:%02d:%02d' $(( $1 / 3600 % 24 )) $(( $1 / 60 % 60 )) $(( $1 % 60 )); }

for i in $(seq 1 2500); do
  t=$(( 3600 + i * 11 ))
  w=$(( i % 6 ))
  if   [ $(( i % 211 )) -eq 0 ]; then echo "$(ts $t) FATAL [worker-$w] out of memory, worker killed"
  elif [ $(( i % 67 )) -eq 0 ];  then echo "$(ts $t) ERROR [db] query timeout after 30000ms (orders)"
  elif [ $(( i % 89 )) -eq 0 ];  then echo "$(ts $t) ERROR [http] upstream inventory returned 502"
  elif [ $(( i % 41 )) -eq 0 ];  then echo "$(ts $t) WARN  [worker-$w] retrying after timeout error"
  elif [ $(( i % 53 )) -eq 0 ];  then echo "$(ts $t) INFO  [http] GET /help/errors 200 4ms"
  elif [ $(( i % 59 )) -eq 0 ];  then echo "$(ts $t) INFO  [worker-$w] job $i finished, 0 errors"
  else echo "$(ts $t) INFO  [worker-$w] processed order $(( 50000 + i * 7 )) in $(( 15 + i % 90 ))ms"
  fi
done > app.log
