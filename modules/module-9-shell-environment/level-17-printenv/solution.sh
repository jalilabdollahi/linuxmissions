#!/bin/bash
# Find the real worker (not worker-metrics), read its frozen environment.
pgrep -af worker
pid=$(pgrep -f 'bin/worker$')
tr '\0' '\n' < /proc/$pid/environ | grep -E '^(DB_HOST|QUEUE|POOL)=' > live.env
cat live.env
# Keys whose live line is not in worker.env.
grep -vxF -f <(grep -v '^#' worker.env) live.env | cut -d= -f1 > stale.txt
cat stale.txt
