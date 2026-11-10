#!/bin/bash
cd deploy/current || exit 1
pwd -L > "$SANDBOX/logical.txt"
pwd -P > "$SANDBOX/physical.txt"
cd - >/dev/null
cat logical.txt physical.txt
