#!/bin/bash
# Starts `indexer` (a python stand-in) with a low RLIMIT_NOFILE (random soft/hard, set with
# ulimit before exec) and many open files, a few below the soft limit. Builds sysroot/
# with the indexer.service unit, a legacy drop-in that the player's drop-in must outrank
# (drop-ins apply in name order), and the stock /etc/security/limits.conf.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p opt/indexer data .lm-state sysroot/etc/security sysroot/etc/systemd/system/indexer.service.d
cat > opt/indexer/indexer.py <<'PY'
#!/usr/bin/env python3
# Stand-in for a search indexer: it opens its segment files and keeps them open.
import os, sys, time
count = int(sys.argv[1])
held = [open(os.path.join(sys.argv[2], "segment-%04d.dat" % i), "rb") for i in range(count)]
print("indexer: %d segments open" % len(held), flush=True)
while True:
    time.sleep(30)
PY
soft=$(shuf -e 128 192 256 320 384 -n 1)
hard=$((soft * $(shuf -e 1 2 4 -n 1)))
n=$((soft - 3 - 5 - RANDOM % 4))            # stdin/out/err + python's own + a margin below the soft limit
for i in $(seq 0 $((n - 1))); do printf 'segment %d\n' "$i" > "data/segment-$(printf %04d "$i").dat"; done
( ulimit -Sn "$soft"; ulimit -Hn "$hard"
  exec python3 "$SANDBOX/opt/indexer/indexer.py" "$n" "$SANDBOX/data" ) >/dev/null 2>&1 &
echo $! > .lm-state/indexer.pid
cat > sysroot/etc/systemd/system/indexer.service <<T
[Unit]
Description=Search indexer
After=network.target

[Service]
ExecStart=/opt/indexer/indexer.py
User=indexer
Restart=on-failure

[Install]
WantedBy=multi-user.target
T
cat > sysroot/etc/systemd/system/indexer.service.d/10-legacy.conf <<'T'
# old workaround from the previous admin
[Service]
LimitNOFILE=1024
T
cat > sysroot/etc/security/limits.conf <<'T'
# /etc/security/limits.conf
#
#<domain>      <type>  <item>         <value>
#
#*               soft    core            0
#*               hard    rss             10000
#@student        hard    nproc           20
#@faculty        soft    nproc           20
#ftp             hard    nproc           0
# End of file
T
cat > TICKET.md <<'T'
# indexer dies with "Too many open files"

The indexer process (running now) crashes under load. Document how it is
limited today in limits.txt, three lines:
  soft=<soft nofile limit>
  hard=<hard nofile limit>
  open=<number of file descriptors it has open right now>
Then fix the limit for good in sysroot/ (a copy of the host's /etc): the
indexer is a systemd service. The running process is a snapshot of the
problem; do not restart it.
T
sleep 1
