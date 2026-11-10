#!/bin/bash
SANDBOX="$1"

mkdir -p "$SANDBOX/old reports" "$SANDBOX/backups"
echo "Q3 numbers" > "$SANDBOX/old reports/q3.csv"
echo "remember to rotate the keys" > "$SANDBOX/my notes.txt"
echo "db_host=10.0.0.8" > "$SANDBOX/settings.conf"

cat > "$SANDBOX/check_file.sh" <<'SCRIPT'
#!/bin/bash
# check_file.sh PATH - say what PATH is before the backup job touches it
#   FILE     PATH is a regular file
#   DIR      PATH is a directory
#   MISSING  nothing there (exit status 1)
# TODO
SCRIPT

chmod +x "$SANDBOX/check_file.sh"
