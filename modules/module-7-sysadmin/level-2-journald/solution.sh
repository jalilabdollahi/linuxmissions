#!/bin/bash
# Filter by unit, priority and time in the journal itself, not with grep.
./journalctl -u myapp.service -p err --since "14:00" > errors.txt
cat errors.txt
