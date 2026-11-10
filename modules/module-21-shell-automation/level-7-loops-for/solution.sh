#!/bin/bash
# Count days from START with date -d "START + i day" until END is passed.
cat > missing_backups.sh <<'SCRIPT'
#!/bin/bash
# missing_backups.sh START END - print the days whose dump is missing or empty.
usage() { echo "usage: missing_backups.sh START END   (YYYY-MM-DD)" >&2; exit 2; }
[ "$#" -eq 2 ] || usage
start=$(date -d "$1" +%F 2>/dev/null) || usage
end=$(date -d "$2" +%F 2>/dev/null) || usage
[[ $end < $start ]] && usage

status=0
for ((i = 0; ; i++)); do
  day=$(date -d "$start + $i day" +%F)
  [[ $day > $end ]] && break
  if [ ! -s "backups/db-$day.sql.gz" ]; then
    echo "$day"
    status=1
  fi
done
exit "$status"
SCRIPT
./missing_backups.sh 2026-10-28 2026-11-03; echo "exit $?"
