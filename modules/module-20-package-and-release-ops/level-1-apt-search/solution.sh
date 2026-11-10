#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
apt-cache search command-line json schema validator | awk '{print $1}' > package.txt
cat package.txt
