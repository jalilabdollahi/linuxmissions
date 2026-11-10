#!/bin/bash
region="$(sed -n 's/^ *APP_REGION: *//p' TICKET.txt)"
export APP_MODE=prod APP_REGION="$region"
declare -p APP_MODE APP_REGION
./launcher.sh
cat run.log
