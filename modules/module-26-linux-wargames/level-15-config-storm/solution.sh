#!/bin/bash
vars='${SVC_NAME} ${LISTEN_PORT} ${DB_HOST} ${DB_USER} ${DB_PASS} ${MAX_CONN}'
for f in env/*.env; do
  svc=$(basename "$f" .env)
  (
    while IFS='=' read -r k v; do export "${k#export }=$v"; done < <(tr -d '\r' < "$f" | grep '=')
    envsubst "$vars" < template.conf > "rendered/$svc.conf"
  )
done
: > drift.txt
for f in env/*.env; do
  svc=$(basename "$f" .env)
  if ! diff -q <(grep -v '^#' "live/$svc.conf" | grep -v '^$') <(grep -v '^#' "rendered/$svc.conf" | grep -v '^$') >/dev/null; then echo "$svc" >> drift.txt; fi
done
sort -o drift.txt drift.txt
cat drift.txt
