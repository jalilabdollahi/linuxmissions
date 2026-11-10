#!/bin/bash
# label-request.txt names the rack letter, the first and the last position.
# The step is always 2; the letter and range differ per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
letters=(a b c d e f g h)
letter=${letters[RANDOM % 8]}
first=$((2 + 2 * (RANDOM % 3)))                 # 2, 4 or 6
last=$((60 + 2 * (RANDOM % 20)))                # 60..98, even
cat > label-request.txt <<REQ
Ticket DC-$((4000 + RANDOM % 900)): B-side PDU outlet labels
rack: $letter
first position: $first
last position: $last
step: 2 (even positions only)
format: rack-<rack>-<position as two digits>
REQ
echo "$letter $first $last" > .lm-state/params
