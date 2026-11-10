#!/bin/bash
# Ten Days of Logs: app-2026-10-1* also catches the .gz copies and the
# malformed names; the hidden .swp file is never matched by *.
SANDBOX="$1"
mkdir -p "$SANDBOX/logs" "$SANDBOX/archive"
cd "$SANDBOX/logs" || exit 1

levels=(INFO INFO INFO WARN INFO ERROR INFO DEBUG)
logfile() {  # logfile NAME LINES
  {
    echo "# $1"
    for i in $(seq 1 "$2"); do
      printf '%02d:%02d:%02d %s request id=%05d took %dms\n' $(( RANDOM % 24 )) $(( RANDOM % 60 )) $(( RANDOM % 60 )) \
        "${levels[$(( RANDOM % 8 ))]}" $(( RANDOM % 100000 )) $(( RANDOM % 900 + 5 ))
    done
  } > "$1"
}

for d in $(seq -w 1 31); do
  logfile "app-2026-10-$d.log" $(( RANDOM % 20 + 5 ))
  # older days were already compressed by logrotate (copy kept, original not yet deleted)
  [ "$d" -le 20 ] && gzip -c "app-2026-10-$d.log" > "app-2026-10-$d.log.gz"
done
for d in 28 29 30; do logfile "app-2026-09-$d.log" 6; done
for d in 01 02 03; do logfile "app-2026-11-$d.log" 6; done
for d in 12 14 17; do logfile "worker-2026-10-$d.log" 4; done
logfile app-2026-10-1.log 3
logfile app-2026-10-100.log 3
logfile .app-2026-10-12.log.swp 2
