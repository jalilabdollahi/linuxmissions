#!/bin/bash
# rsync -a copies with attributes; --link-dest hard-links files identical to the
# ones in that directory (a relative path is relative to the DESTINATION), and
# --delete is not needed for a fresh destination.
rsync -a site/ snapshots/day1/
./change-day.sh
rsync -a --link-dest=../day1 site/ snapshots/day2/
ls -li snapshots/day1/pages snapshots/day2/pages
du -sh snapshots/day1 snapshots/day2 snapshots
