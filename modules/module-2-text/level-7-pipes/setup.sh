#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# A morning of API traffic in nginx "combined" format. A fixed-seed generator
# keeps the file identical on every machine.
ips=(10.0.1.1 10.0.1.2 10.0.1.3 10.0.1.4 172.16.0.8 172.16.0.9 192.168.5.20 192.168.5.21 \
     192.168.5.22 198.51.100.7 198.51.100.8 203.0.113.40 203.0.113.41 203.0.113.42 \
     66.249.66.1 66.249.66.2)
post_pct=(55 41 33 28 24 19 16 13 11 9 7 5 3 1 0 0)   # how often each client POSTs
agents=('python-requests/2.31' 'PostmanRuntime/7.36.0' 'Mozilla/5.0 (X11; Linux x86_64) Firefox/123.0' 'okhttp/4.12')

r=20240316
for i in $(seq 1 1500); do
  r=$(( (r * 1103515245 + 12345) % 2147483648 ))
  k=$(( (r >> 8) % 16 ))
  m=$(( (r >> 3) % 100 ))
  p=${post_pct[$k]}
  if [ $k -ge 14 ]; then
    # crawlers: GET only, and they like the docs pages whose names contain POST
    method=GET; if [ $(( m % 2 )) -eq 0 ]; then path=/docs/POST-requests; else path=/blog/how-to-POST-json; fi
  elif [ $m -lt $p ]; then
    method=POST; if [ $(( m % 2 )) -eq 0 ]; then path=/api/orders; else path=/api/cart/items; fi
  elif [ $m -lt $(( p + 6 )) ]; then method=PUT; path=/api/cart/items/$(( r % 40 ))
  elif [ $m -lt $(( p + 9 )) ]; then method=DELETE; path=/api/cart/items/$(( r % 40 ))
  elif [ $(( m % 9 )) -eq 0 ]; then method=GET; path=/docs/POST-requests
  else method=GET; path=/api/products/$(( r % 300 ))
  fi
  case $method in POST) status=201 ;; DELETE) status=204 ;; *) status=200 ;; esac
  t=$(( 21600 + i * 17 ))
  printf '%s - - [16/Mar/2024:%02d:%02d:%02d +0000] "%s %s HTTP/1.1" %s %d "-" "%s"\n' \
    "${ips[$k]}" $(( t / 3600 )) $(( t / 60 % 60 )) $(( t % 60 )) "$method" "$path" \
    "$status" $(( 90 + r % 3000 )) "${agents[$(( (i + k) % 4 ))]}"
done > access.log
