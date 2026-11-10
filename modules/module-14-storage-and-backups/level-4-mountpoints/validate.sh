#!/bin/bash
# 1) backup.sh with a TARGET that "mountpoint" says is not mounted: exit != 0 and
#    nothing written. 2) with a mountpoint stand-in returning 0: the data is
#    backed up under TARGET. 3) mnt/backup is empty and stray/ holds exactly the
#    files that were misplaced (compared by content).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

[ -f backup.sh ] || { echo "❌ backup.sh is missing"; exit 1; }

W=$(mktemp -d "$SANDBOX/.lm-state/val.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src/sub" "$W/bin"
for i in 1 2 3; do echo "fixture $RANDOM$RANDOM $i" > "$W/src/file$i.dat"; done
echo "fixture $RANDOM$RANDOM nested" > "$W/src/sub/inner file.txt"

stub() { printf '#!/bin/sh\nexit %s\n' "$1" > "$W/bin/mountpoint"; chmod +x "$W/bin/mountpoint"; }

# negative case
mkdir -p "$W/not-mounted"
stub 1
PATH="$W/bin:$PATH" SRC="$W/src" TARGET="$W/not-mounted" bash backup.sh >/dev/null 2>&1
code=$?
if [ -n "$(find "$W/not-mounted" -mindepth 1 2>/dev/null | head -1)" ]; then
  echo "❌ backup.sh wrote into a target that is not a mount point (a plain directory test is always true)"
  exit 1
fi
if [ "$code" -eq 0 ]; then
  echo "❌ backup.sh exits 0 although the target is not mounted; it must fail so cron reports it"
  exit 1
fi

# positive case
mkdir -p "$W/mounted"
stub 0
PATH="$W/bin:$PATH" SRC="$W/src" TARGET="$W/mounted" bash backup.sh >/dev/null 2>&1
code=$?
if [ "$code" -ne 0 ]; then
  echo "❌ backup.sh fails even when mountpoint reports a mounted target (exit $code); is it calling mountpoint through PATH?"
  exit 1
fi
for f in file1.dat file2.dat file3.dat "sub/inner file.txt"; do
  hit=$(find "$W/mounted" -type f -path "*/$f" 2>/dev/null | head -1)
  if [ -z "$hit" ] || ! cmp -s "$hit" "$W/src/$f"; then
    echo "❌ with the target mounted the backup is incomplete: '$f' was not copied"
    exit 1
  fi
done

# cleaning up the stray files
left=$(find mnt/backup -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
if [ ! -d mnt/backup ]; then
  echo "❌ mnt/backup must still exist (as an empty directory) so the disk can be mounted over it"
  exit 1
fi
if [ "$left" -ne 0 ]; then
  echo "❌ mnt/backup still contains $left entr$([ "$left" = 1 ] && echo y || echo ies); hidden (dot) directories are easy to miss"
  exit 1
fi
if [ ! -d stray ]; then
  echo "❌ stray/ does not exist yet"
  exit 1
fi
find stray -type f -exec sha256sum {} + 2>/dev/null | cut -d' ' -f1 | sort > "$W/stray.sums"
if ! cmp -s "$W/stray.sums" .lm-state/orig.sums; then
  have=$(wc -l < "$W/stray.sums" | tr -d ' '); want=$(wc -l < .lm-state/orig.sums | tr -d ' ')
  if [ "$have" -lt "$want" ]; then
    echo "❌ stray/ holds $have of the $want misplaced files"
  elif [ "$have" -gt "$want" ]; then
    echo "❌ stray/ holds $have files, more than the $want that were misplaced; only move what was written into mnt/backup"
  else
    echo "❌ stray/ has the right number of files but not the original contents; move the files, do not change them"
  fi
  exit 1
fi
echo "✅ backup.sh now refuses an unmounted target, and the ${want:-$(wc -l < .lm-state/orig.sums | tr -d ' ')} stray files are in stray/"
exit 0
