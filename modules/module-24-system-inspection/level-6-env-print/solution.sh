#!/bin/bash
pid=$(pgrep -f 'worker\.py')
tr '\0' '\n' < /proc/$pid/environ | grep -E '^(APP_ENV|DB_HOST)=' | sort -t= -k1,1 > worker_env.txt
cat worker_env.txt
