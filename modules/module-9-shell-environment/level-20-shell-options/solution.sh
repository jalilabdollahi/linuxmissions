#!/bin/bash
# Turn on the glob options and noclobber inside the script, and use ** for depth.
sed -i.bak -e 's|^files=0$|shopt -s nullglob globstar nocaseglob\nset -o noclobber\nfiles=0|' \
           -e 's|^for f in incoming/\*\.csv; do$|for f in incoming/**/*.csv; do|' ingest.sh
rm -f ingest.sh.bak
grep -n -e shopt -e noclobber -e 'for f' ingest.sh
./ingest.sh
