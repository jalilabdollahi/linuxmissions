#!/bin/bash
export PATH="$PWD/bin:$PATH"   # the game shell already has bin/ first on PATH
journalctl --list-boots
journalctl -p err --since 23:40          # "-- No entries --": 23:40 *today* hasn't happened yet
# Give the full date of the start; no -b, the window spans the reboot.
journalctl -p err --since "2026-11-09 23:40" -o short-iso > errors.txt
cat errors.txt
