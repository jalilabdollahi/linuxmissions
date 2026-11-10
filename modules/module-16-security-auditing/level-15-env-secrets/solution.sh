#!/bin/bash
ps -eo pid,args | grep '[w]orker.sh'
pid=$(pgrep -f -- '--password=')
echo "$pid" > leak.txt
pw=$(ps -o args= -p "$pid" | sed 's/.*--password=//')
( umask 077; printf '%s\n' "$pw" > secrets/db.pass )
kill "$pid"
sed -i -e '/^DB_PASSWORD=/d' -e 's|^nohup|PASSWORD_FILE="$PWD/secrets/db.pass" nohup|' -e 's| --password="$DB_PASSWORD"||' app/start-worker.sh
bash app/start-worker.sh
