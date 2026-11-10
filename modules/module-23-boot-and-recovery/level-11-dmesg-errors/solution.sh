#!/bin/bash
# Errors name ata3; the probe lines tie ata3 to scsi 2:0:0:0 and to [sdb].
grep -nE 'error|failed|exception' dmesg.txt | head -20
grep -E 'ata3|2:0:0:0' dmesg.txt | head -12
grep -m1 'ata3.00: exception' dmesg.txt | sed -E 's/^\[ *([0-9.]+)\].*/sdb \1/' > failing_disk.txt
cat failing_disk.txt
