#!/bin/bash
SANDBOX="$1"
echo "# Find the top 5 CPU-consuming processes on this system" > "$SANDBOX/README"
echo "# Save the result to: $SANDBOX/top_procs.txt" >> "$SANDBOX/README"
