#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# A day of web traffic in nginx "combined" format (deterministic, same on every machine)
paths=(/ /products /products/42 /cart /api/cart /static/app.js /login)
agents=('Mozilla/5.0 (X11; Linux x86_64) Firefox/123.0' 'curl/8.5.0' \
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3) Safari/605.1' 'Googlebot/2.1 (+http://www.google.com/bot.html)')
for i in $(seq 1 1200); do
  k=$(( (i * i * 3 + i * 7) % 61 ))
  if [ $k -lt 20 ]; then ip="10.0.$(( k % 3 )).$(( k * 11 + 4 ))"; else ip="203.0.113.$(( k * 3 ))"; fi
  t=$(( i * 71 ))
  date=$(printf '14/Mar/2024:%02d:%02d:%02d +0000' $(( t / 3600 % 24 )) $(( t / 60 % 60 )) $(( t % 60 )))
  path=${paths[$(( i % 7 ))]}
  method=GET; [ "$path" = /api/cart ] && method=POST
  if   [ $(( i % 13 )) -eq 0 ]; then status=304; bytes=-
  elif [ $(( i % 29 )) -eq 0 ]; then status=404; bytes=153
  else status=200; bytes=$(( (i * 7919) % 48000 + 120 ))
  fi
  printf '%s - - [%s] "%s %s HTTP/1.1" %s %s "-" "%s"\n' \
    "$ip" "$date" "$method" "$path" "$status" "$bytes" "${agents[$(( i % 4 ))]}"
done > access.log
