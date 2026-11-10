#!/bin/bash
# ESTAB rows whose local side is :443; strip the peer port; count per peer.
awk '$1 == "ESTAB" && $4 ~ /:443$/ { sub(/:[0-9]+$/, "", $5); print $5 }' connections.txt \
  | sort | uniq -c | sort -nr | head -1 | awk '{ print $2, $1 }' > top_talker.txt
cat top_talker.txt
