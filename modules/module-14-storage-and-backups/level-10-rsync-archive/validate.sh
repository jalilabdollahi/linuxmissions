#!/bin/bash
# new-server/www must match www in structure, types, modes, mtimes, symlink targets and
# hard-link groups, with no shared inodes (a real copy); second-run.txt is empty and
# was written after the copy.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -d new-server/www ]; then
  echo "❌ new-server/www does not exist yet"
  exit 1
fi
if [ -e new-server/www/www ]; then
  echo "❌ new-server/www/www exists: the source was given without the trailing slash, so rsync copied the directory itself into the target"
  exit 1
fi

desc() {
  (cd "$1" && find . \( -type l -printf '%P\tl\t777\t0\t%l\n' \) -o \( -printf '%P\t%y\t%m\t%Ts\t\n' \) | LC_ALL=C sort)
}
S=$(desc www); D=$(desc new-server/www)
missing=$(comm -23 <(printf '%s\n' "$S" | cut -f1 | sort) <(printf '%s\n' "$D" | cut -f1 | sort) | head -1)
if [ -n "$missing" ]; then
  echo "❌ '$missing' (and maybe more) from www is missing in new-server/www"
  exit 1
fi
extra=$(comm -13 <(printf '%s\n' "$S" | cut -f1 | sort) <(printf '%s\n' "$D" | cut -f1 | sort) | head -1)
if [ -n "$extra" ]; then
  echo "❌ new-server/www has '$extra', which is not in www"
  exit 1
fi
bad=$(awk -F'\t' 'NR == FNR { t[$1] = $2; m[$1] = $3; s[$1] = $4; l[$1] = $5; next }
  {
    if ($2 != t[$1]) { printf "type\t%s\t%s\t%s\n", $1, t[$1], $2; exit }
    if ($2 == "l" && $5 != l[$1]) { printf "target\t%s\n", $1; exit }
    if ($3 != m[$1]) { printf "mode\t%s\t%s\t%s\n", $1, m[$1], $3; exit }
    if ($4 != s[$1]) { printf "time\t%s\n", $1; exit }
  }' <(printf '%s\n' "$S") <(printf '%s\n' "$D"))
if [ -n "$bad" ]; then
  IFS=$'\t' read -r kind path a b <<< "$bad"
  [ -n "$path" ] || path=new-server/www
  case "$kind" in
    type) if [ "$a" = l ]; then echo "❌ '$path' is a symlink in www but not in the copy: symlinks must be copied as links, not followed"
          else echo "❌ '$path' has a different file type in the copy"; fi ;;
    target) echo "❌ the symlink '$path' points somewhere else in the copy" ;;
    mode) echo "❌ '$path' has mode $b in the copy, www has $a: permissions (setuid, sticky included) must be preserved" ;;
    time) echo "❌ '$path' has a different modification time in the copy: times must be preserved" ;;
  esac
  exit 1
fi

links() {
  (cd "$1" && find . -type f -links +1 -printf '%i\t%P\n' | LC_ALL=C sort -k1,1n -k2 |
     awk -F'\t' '{ if ($1 != p) { lead = $2; p = $1 } print $2 "\t" lead }' | LC_ALL=C sort)
}
if [ "$(links www)" != "$(links new-server/www)" ]; then
  echo "❌ hard links were not preserved: files that share data in www must share it in the copy too"
  exit 1
fi
shared=$(comm -12 <(find www -type f -printf '%i\n' | sort -u) <(find new-server/www -type f -printf '%i\n' | sort -u) | head -1)
if [ -n "$shared" ]; then
  echo "❌ some files in new-server/www are hard links to www itself: the copy must have its own data"
  exit 1
fi

if [ ! -f second-run.txt ]; then
  echo "❌ the tree is an exact copy, but second-run.txt does not exist yet"
  exit 1
fi
if [ -s second-run.txt ]; then
  echo "❌ second-run.txt is not empty: the second run still found something to change"
  exit 1
fi
newest=$(find new-server -printf '%C@\n' | sort -n | tail -1)
mine=$(stat -c %Y.%y second-run.txt | cut -d. -f1)
if awk -v a="$newest" -v b="$mine" 'BEGIN { exit !(a > b + 1) }'; then
  echo "❌ second-run.txt is older than the copy: save the output of a second run made after copying"
  exit 1
fi
echo "✅ new-server/www is an exact copy (modes, times, symlinks, hard links) and the second run has nothing left to do"
exit 0
