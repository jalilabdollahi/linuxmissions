#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/shared"
echo "Q3 budget draft"      > "$SANDBOX/shared/alice_budget.xlsx"
echo "conference photos"    > "$SANDBOX/shared/bob_photos.zip"
echo "meeting notes 12 Oct" > "$SANDBOX/shared/carol_notes.txt"
chmod 644 "$SANDBOX/shared/"*
chmod 0777 "$SANDBOX/shared"     # world-writable, no sticky bit
