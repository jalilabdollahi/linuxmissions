#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p staging production

# What is live right now (release 4.1)
printf '# app.conf - release 4.1 (live)\nlisten=8080\nworkers=4\ncheckout=legacy\n' > production/app.conf
printf 'host=db-old.internal\n' > production/db.conf

# Release 4.2, dropped in the wrong place
printf '# app.conf - release 4.2\nlisten=8080\nworkers=8\ncheckout=v2\n' > staging/app.conf.new
printf 'host=db-primary.internal\nport=5432\npool=20\n' > staging/db.conf
printf 'server_name=shop.example.com\nport=443\n' > staging/web.conf
printf 'level=info\nformat=json\n' > staging/logging.conf
printf 'backend=redis\nttl=300\n' > staging/cache.conf
printf 'Release 4.2 notes: new checkout, more workers.\n' > staging/notes.txt
