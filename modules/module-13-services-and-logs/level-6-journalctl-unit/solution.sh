#!/bin/bash
export PATH="$PWD/bin:$PATH"   # the game shell already has bin/ first on PATH
cat TICKET.txt
from=$(grep -o '2026-11-10 [0-9:]* to' TICKET.txt | cut -d' ' -f1,2)
to="2026-11-10 $(grep -o 'to [0-9:]*' TICKET.txt | cut -d' ' -f2)"
journalctl -u payment.service --since "$from" --until "$to" -o cat > payment.txt
cat payment.txt
