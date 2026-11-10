#!/bin/bash
# The nightly backup "succeeded" all week but the USB disk is empty: it was not
# mounted, so backup.sh wrote into the bare mnt/backup directory. backup.sh
# guards with [ -d ], which is true either way. mnt/backup holds five days of
# dated backup dirs, one of them dot-prefixed (so `mv mnt/backup/*` misses it).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state mnt/backup data

cat > backup.sh <<'EOF'
#!/bin/bash
# Nightly backup of the application data to the USB disk.
# SRC and TARGET can be overridden from the environment.
cd "$(dirname "$0")" || exit 1
SRC=${SRC:-data}
TARGET=${TARGET:-mnt/backup}

if [ ! -d "$TARGET" ]; then
  echo "backup target $TARGET is missing" >&2
  exit 1
fi

dest="$TARGET/$(date +%F)"
mkdir -p "$dest"
cp -a "$SRC"/. "$dest"/
echo "backup written to $dest"
EOF
chmod +x backup.sh

echo "customers.csv orders.csv config.ini" | tr ' ' '\n' | while read -r f; do
  echo "live data $RANDOM $f" > "data/$f"
done

dotted=$((1 + RANDOM % 5))
for d in 1 2 3 4 5; do
  day=$(date -d "$d days ago" +%F 2>/dev/null || date -v-"$d"d +%F)
  dir="mnt/backup/$day"
  [ "$d" = "$dotted" ] && dir="mnt/backup/.$day"
  mkdir -p "$dir"
  for f in customers.csv orders.csv config.ini; do
    echo "backup of $day $f token $RANDOM$RANDOM" > "$dir/$f"
  done
  [ $((RANDOM % 2)) = 0 ] && echo "report for $day $RANDOM$RANDOM" > "$dir/nightly report.txt"
done

cat > TICKET.txt <<'EOF'
Backups have been "succeeding" all week, but when we plugged in the USB backup
disk it was empty. Ops found out the disk was not mounted at /mnt/backup, so
backup.sh quietly wrote everything into the bare directory on the system disk
(here: mnt/backup), which is also why the root disk is filling up.

1. backup.sh must refuse to run unless the target is really a mounted file
   system. The check must call `mountpoint` (found through PATH, not by its
   full path): the test harness puts its own stand-in first on PATH.
2. Move everything that was written into the bare directory to stray/ so it can
   be reviewed, and leave mnt/backup empty, ready to be mounted over.
EOF

find mnt/backup -type f -exec sha256sum {} + | cut -d' ' -f1 | sort > .lm-state/orig.sums
