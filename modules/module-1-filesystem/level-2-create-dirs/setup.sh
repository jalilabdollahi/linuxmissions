#!/bin/bash
# Sandbox is empty — player must create the required structure
SANDBOX="$1"
echo "# Create the required directories inside: $SANDBOX" > "$SANDBOX/README"
