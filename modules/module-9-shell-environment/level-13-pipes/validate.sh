#!/bin/bash
# Every run of build.sh appends "<id> <key> <total^key> <stdout^key> <status^key>"
# (hex) to .build/history. The two answer files must match ONE of those runs:
# all WARN lines (stdout + stderr) and build.sh's own exit status.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .build/history ]; then
  echo "❌ build.sh has not been run yet (or .build/history was removed; type reset)"
  exit 1
fi

read_number() {  # read_number FILE -> prints the number, or nothing
  [ -f "$1" ] || return 1
  local v
  v="$(tr -d '[:space:]' < "$1")"
  case "$v" in
    ''|*[!0-9]*) return 2 ;;
  esac
  echo "$v"
}

wc_val="$(read_number warn_count.txt)"
case $? in
  1) echo "❌ warn_count.txt does not exist yet"; exit 1 ;;
  2) echo "❌ warn_count.txt should contain just a number (the count of WARN lines)"; exit 1 ;;
esac
st_val="$(read_number build_status.txt)"
case $? in
  1) echo "❌ build_status.txt does not exist yet"; exit 1 ;;
  2) echo "❌ build_status.txt should contain just a number (build.sh's exit status)"; exit 1 ;;
esac
wc_val=$(( 10#$wc_val )); st_val=$(( 10#$st_val ))

stdout_only=0; total_seen=0
while read -r id key t o s; do
  case "$key$t$o$s" in ''|*[!0-9a-f]*) continue ;; esac
  key=$(( 16#$key )); total=$(( 16#$t ^ key )); outw=$(( 16#$o ^ key )); status=$(( 16#$s ^ key ))
  if [ "$wc_val" -eq "$total" ] && [ "$st_val" -eq "$status" ]; then
    echo "✅ build $id: $total WARN lines on stdout and stderr, and build.sh exited with $status"
    exit 0
  fi
  [ "$wc_val" -eq "$outw" ] && stdout_only=1
  [ "$wc_val" -eq "$total" ] && total_seen=1
done < .build/history

if [ "$stdout_only" -eq 1 ] && [ "$total_seen" -eq 0 ]; then
  echo "❌ warn_count.txt ($wc_val) counts only the warnings on stdout; the compiler warnings go to stderr, which a plain | does not carry"
elif [ "$st_val" -eq 0 ]; then
  echo "❌ build_status.txt says 0, but build.sh did not succeed; after a pipeline, \$? is the status of the LAST command (grep)"
elif [ "$total_seen" -eq 1 ]; then
  echo "❌ build_status.txt ($st_val) is not the exit status of the run that printed $wc_val warnings; take both numbers from the same run"
else
  echo "❌ warn_count.txt ($wc_val) does not match the number of WARN lines of any build.sh run so far"
fi
exit 1
