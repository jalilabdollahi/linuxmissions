#!/bin/bash
# Follow the log by name, from now on, before triggering; stop at the first token.
timeout 60 tail -n0 -F var/log/deploy/deploy.log | grep -m1 'one-time admin token' | grep -o 'adm_[A-Za-z0-9]*' > token.txt &
sleep 1
./trigger-deploy.sh
wait
cat token.txt
