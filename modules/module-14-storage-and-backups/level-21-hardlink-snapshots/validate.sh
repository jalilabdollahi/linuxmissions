#!/bin/bash
# day1 equals the original tree, day2 equals the changed tree (content, mode, mtime);
# unchanged files share an inode, changed ones do not; day files are not linked to site/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
state() { ( cd "$1" && find . -type f -print0 | while IFS= read -r -d '' p; do
    printf '%s\t%s\t%s\t%s\n' "$p" "$(stat -c %a "$p")" "$(stat -c %Y "$p")" "$(sha256sum < "$p" | cut -d' ' -f1)"
  done | LC_ALL=C sort ); }
[ -d snapshots/day1 ] || { echo "❌ snapshots/day1 does not exist yet"; exit 1; }
[ -d snapshots/day2 ] || { echo "❌ snapshots/day2 does not exist yet"; exit 1; }
if [ "$(state site)" != "$(cat .lm-state/day2.tsv)" ]; then
  echo "❌ site/ is not in the state after change-day.sh (run ./change-day.sh once, in place, and do not touch site/ otherwise)"
  exit 1
fi
s1=$(state snapshots/day1)
if [ "$s1" != "$(cat .lm-state/day1.tsv)" ]; then
  if [ "$(cut -f1,4 <<< "$s1")" = "$(cut -f1,4 .lm-state/day2.tsv)" ]; then
    echo "❌ snapshots/day1 shows the site AFTER the changes: it has to be taken before ./change-day.sh (or it was hard-linked to site/ and followed the edits)"
  else
    echo "❌ snapshots/day1 is not a faithful copy of the original site (content, modes or mtimes differ, or files are missing/extra; a hard-linked copy of site/ follows later in-place edits)"
  fi
  exit 1
fi
s2=$(state snapshots/day2)
if [ "$s2" != "$(cat .lm-state/day2.tsv)" ]; then
  gone=$(comm -13 <(cut -f1 <<< "$s2") <(cut -f1 .lm-state/day2.tsv) | head -1)
  extra=$(comm -23 <(cut -f1 <<< "$s2") <(cut -f1 .lm-state/day2.tsv) | head -1)
  if [ -n "$extra" ]; then echo "❌ snapshots/day2 has $extra, which was deleted from site/"
  elif [ -n "$gone" ]; then echo "❌ snapshots/day2 is missing $gone"
  else echo "❌ snapshots/day2 differs from the current site/ (content, mode or modification time: copy with the attributes preserved)"; fi
  exit 1
fi
# links between days
shared=0; separate=0
while IFS=$'\t' read -r p m t h; do
  if grep -qP "^\Q$p\E\t$m\t$t\t$h\$" .lm-state/day1.tsv; then
    if [ "$(stat -c %i "snapshots/day1/$p")" != "$(stat -c %i "snapshots/day2/$p")" ]; then
      echo "❌ $p is identical in day1 and day2 but stored twice (not the same inode): link unchanged files to the previous snapshot"
      exit 1
    fi
    shared=$((shared + 1))
  else
    if [ -e "snapshots/day1/$p" ] && [ "$(stat -c %i "snapshots/day1/$p")" = "$(stat -c %i "snapshots/day2/$p")" ]; then
      echo "❌ $p changed on day 2 but day1 and day2 share one inode: day1 would show the new version"
      exit 1
    fi
    separate=$((separate + 1))
  fi
done < .lm-state/day2.tsv
if [ "$(find snapshots/day1 snapshots/day2 -type f -printf '%i\n' | sort -u | wc -l)" -gt 0 ]; then
  while read -r i; do
    if grep -qx "$i" .lm-state/site-inodes0; then echo "❌ a snapshot file shares its inode with a file of the live site/: later edits there would alter the snapshot"; exit 1; fi
  done < <(find snapshots/day1 snapshots/day2 -type f -printf '%i\n' | sort -u)
fi
echo "✅ day1 and day2 are complete snapshots; $shared unchanged files are stored once, $separate changed or new files separately"
