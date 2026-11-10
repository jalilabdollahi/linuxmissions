#!/bin/bash
serial=$(grep -o 'serial number [A-Z0-9]*' TICKET.md | awk '{print $3}')
jq -r --arg s "$serial" '
  .blockdevices[] | select(.serial == $s)
  | "/dev/" + .name,
    ([.. | .mountpoints? // empty | .[] | select(. != null and startswith("/"))] | unique | .[])' \
  capture/lsblk.json > disk.txt
cat disk.txt
