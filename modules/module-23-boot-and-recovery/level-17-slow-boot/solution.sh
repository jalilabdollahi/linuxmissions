#!/bin/bash
U=$(grep -E '\+[0-9]+min' critical-chain.txt | sed -E 's/^[^A-Za-z]*([^ ]+\.service).*/\1/'); echo "$U" > slow_unit.txt; cat slow_unit.txt
mkdir -p sysroot/etc/systemd/system/$U.d
CMD=$(grep -m1 '^ExecStart=' sysroot/usr/lib/systemd/system/$U | sed 's/^ExecStart=//; s/ --timeout=[0-9]*//')
printf '[Service]\nExecStart=\nExecStart=%s --timeout=10\n' "$CMD" > sysroot/etc/systemd/system/$U.d/override.conf
cat sysroot/etc/systemd/system/$U.d/override.conf
