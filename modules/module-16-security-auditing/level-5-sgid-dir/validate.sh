#!/bin/bash
# Every directory: original mode | 2000. Every regular file: original mode
# (so never setgid). No entry added or removed, contents unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
[ -s .lm-state/modes ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -d projects ] || { echo "❌ projects/ is missing"; exit 1; }
[ "$(find projects | wc -l | tr -d ' ')" = "$(wc -l < .lm-state/modes | tr -d ' ')" ] || { echo "❌ entries were added to or removed from projects/"; exit 1; }

# files first: a setgid file is the more serious mistake
while IFS=$'\t' read -r p old; do
  [ -f "$p" ] || continue
  got=$(mode "$p")
  if [ $((8#$got & 8#2000)) -ne 0 ]; then
    echo "❌ the file $p has the setgid bit: only directories should get it (on a program it means \"run with this file's group\")"; exit 1
  fi
  if [ "$got" != "$old" ]; then echo "❌ the mode of the file $p was changed ($old -> $got)"; exit 1; fi
done < .lm-state/modes
while IFS=$'\t' read -r p old; do
  [ -d "$p" ] || continue
  got=$(mode "$p")
  if [ $((8#$got & 8#2000)) -eq 0 ]; then echo "❌ the directory $p does not pass its group on to new files yet"; exit 1; fi
  want=$(printf '%o' $((8#$old | 8#2000)))
  if [ "$got" != "$want" ]; then echo "❌ the directory $p has mode $got, but only the setgid bit should have been added to it"; exit 1; fi
done < .lm-state/modes
if ! find projects -type f | LC_ALL=C sort | while IFS= read -r p; do cksum < "$p" | sed "s|^|$p\t|"; done | cmp -s - .lm-state/sums; then
  echo "❌ the content of a file was changed"; exit 1
fi
echo "✅ all $(find projects -type d | wc -l | tr -d ' ') directories are setgid and no file is"
exit 0
