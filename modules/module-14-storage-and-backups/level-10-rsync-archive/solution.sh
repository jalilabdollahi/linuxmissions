#!/bin/bash
# -a keeps modes, times and symlinks, -H keeps hard links. The trailing slash on
# the source copies its contents into new-server/www/. A dry itemized second run
# prints one line for every difference left (none here).
mkdir -p new-server/www
rsync -aH www/ new-server/www/
rsync -aHni www/ new-server/www/ > second-run.txt
cat second-run.txt
