#!/bin/bash
# Resume the uploader, wait until spool/ has no entries at all (ls -A also
# lists the hidden .part files), then switch. watch -g needs a terminal, so
# this script polls with an until loop; at the game prompt the hint uses watch.
./resume-uploads.sh
until [ -z "$(ls -A spool)" ]; do
  sleep 1
done
./switch-traffic.sh
