#!/bin/bash
export PATH="$PWD/bin:$PATH"   # the game shell already has bin/ first on PATH
# Nothing is "failed", so --failed is empty. List every service unit and
# look at the ACTIVE/SUB columns: one is stuck in activating/auto-restart.
systemctl --failed
systemctl list-units --type=service --all
unit=$(systemctl list-units --type=service --state=activating --plain --no-legend | awk '{ print $1 }')
systemctl status "$unit"
# The exit status of the last run of its main process:
code=$(systemctl show -P ExecMainStatus "$unit")
echo "$unit $code" > diagnosis.txt
cat diagnosis.txt
