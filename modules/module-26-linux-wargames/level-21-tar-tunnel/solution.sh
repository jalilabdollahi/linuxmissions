#!/bin/bash
tar -C alpha -cf - data | base64 > payload.b64
split -b 60000 -d -a 3 payload.b64 part.
for f in part.*; do { echo "SEQ ${f#part.}"; cat "$f"; } > "msg.${f#part.}"; ./relay send "msg.${f#part.}"; done
for f in bravo/inbox/*; do echo "$(head -1 "$f" | cut -d' ' -f2) $f"; done | sort | while read -r n f; do tail -n +2 "$f"; done | base64 -d | tar -xpf - -C bravo
rm -f payload.b64 part.* msg.*
