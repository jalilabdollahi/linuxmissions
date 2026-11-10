#!/bin/bash
# An nginx.conf of 100-170 lines made of random-ish server blocks, comments,
# blank lines (single and double) and an indented block with whitespace-only lines.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

{
  echo "user www-data;"
  echo "worker_processes $((1 + RANDOM % 8));"
  echo
  echo "events {"
  echo "    worker_connections $((512 * (1 + RANDOM % 4)));"
  echo "}"
  echo
  echo "http {"
  echo "    include       mime.types;"
  echo "    sendfile      on;"
  echo "    keepalive_timeout $((30 + RANDOM % 60));"
  echo
  names=(shop api blog admin static docs status mail git)
  nsrv=$((4 + RANDOM % 4))
  for ((s = 0; s < nsrv; s++)); do
    n=${names[(s + RANDOM % 3) % 9]}$s
    echo "    # --- $n.example.org ---"
    echo "    server {"
    echo "        listen $((8000 + RANDOM % 900));"
    echo "        server_name $n.example.org;"
    [ $((RANDOM % 3)) -eq 0 ] && { echo; echo "        # TODO: tighten before launch"; }
    echo "        access_log /var/log/nginx/$n.log;"
    echo
    for ((l = 0; l < 1 + RANDOM % 3; l++)); do
      echo "        location /$n$l/ {"
      echo "            proxy_pass http://10.0.$((RANDOM % 5)).$((10 + RANDOM % 80)):$((3000 + RANDOM % 900));"
      [ $((RANDOM % 2)) -eq 0 ] && echo "            proxy_set_header Host \$host;"
      [ $((RANDOM % 4)) -eq 0 ] && { echo "        "; echo "            allow 0.0.0.0/0;"; }
      echo "        }"
      [ $((RANDOM % 2)) -eq 0 ] && { echo; echo; }
    done
    echo "    }"
    echo
  done
  echo "}"
} > nginx.conf
cksum < nginx.conf > .lm-state/conf.sum
