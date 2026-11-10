#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
apt-get -s remove libold1 | awk '/^Remv/ { print $2 }' | grep -vx libold1 | sort > impact.txt
