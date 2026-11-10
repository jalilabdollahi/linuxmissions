#!/bin/bash
# findmnt can read a saved mountinfo with -F. Two mounts share the target;
# the later one in the file is on top.
findmnt -F capture/mountinfo -nl -o TARGET,SOURCE,FSTYPE,VFS-OPTIONS | awk '$1 == "/var/lib/ci/work"' | tail -1 > mount.txt
cat mount.txt
