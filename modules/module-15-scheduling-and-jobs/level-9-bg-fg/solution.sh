#!/bin/bash
# A script has no job control by default; turn it on so %1 works as in a shell.
set -m
./export.sh &
sleep 3
kill -STOP %1
./snapshot.sh
bg %1
wait %1
tail -n 2 export.log
