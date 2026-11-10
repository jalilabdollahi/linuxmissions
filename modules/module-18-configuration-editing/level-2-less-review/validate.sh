#!/bin/bash
# answer.txt = server-level client_max_body_size of the uploads.example.com vhost.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum nginx-full.conf 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ nginx-full.conf was changed; it is the evidence, so type 'reset' to get it back"
  exit 1
fi
if [ ! -f answer.txt ]; then
  echo "❌ answer.txt does not exist yet"
  exit 1
fi
got=$(tr -d '[:space:]' < answer.txt)
want=$(cat .lm-state/answer)
if [ -z "$got" ]; then
  echo "❌ answer.txt is empty"
  exit 1
fi
if [ "$got" = "$want" ]; then
  echo "✅ uploads.example.com allows request bodies up to $want at the server level"
  exit 0
fi
if [ "$got" = "$(cat .lm-state/nested)" ]; then
  echo "❌ $got is the limit of one location block inside the vhost, not the value of the server block itself"
  exit 1
fi
if [ "$got" = "$(cat .lm-state/old)" ]; then
  echo "❌ $got only appears in a comment about an old value"
  exit 1
fi
if [ "$got" = "1m" ]; then
  echo "❌ 1m is the global default in the http block; the vhost sets its own value"
  exit 1
fi
if grep -q "client_max_body_size $got;" nginx-full.conf; then
  echo "❌ $got is a real value, but it belongs to another virtual host"
else
  echo "❌ '$got' does not appear as a client_max_body_size in nginx-full.conf (write only the value, like 10m)"
fi
exit 1
