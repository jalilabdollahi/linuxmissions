#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
apt-cache policy agentd
apt-get update
apt-cache policy agentd | awk '/Candidate:/ {print $2}' > candidate.txt
cat candidate.txt
