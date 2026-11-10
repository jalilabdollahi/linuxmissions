#!/bin/bash
T=srv/projects/apollo
# directories: rwx for owner+team, nothing for others, setgid + sticky
find $T -type d -exec chmod 3770 {} +
# files that are executable today stay executable; the rest become plain rw
find $T -type f -perm /111 -exec chmod 770 {} +
find $T -type f ! -perm /111 -exec chmod 660 {} +
find $T -printf '%m %p\n' | sort -k2 | head -n 12
