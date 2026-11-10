#!/bin/bash
# quarantine/ = exactly the two damaged files, dumps/ = the intact .bz2 files,
# restore/ = one correct .sql per intact dump.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
for f in bad bz2.sums sql.sums; do
  if [ ! -s ".lm-state/$f" ]; then
    echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
    exit 1
  fi
done
read -r bad1 bad2 < .lm-state/bad
is_bad() { [ "$1" = "$bad1" ] || [ "$1" = "$bad2" ]; }

# Every original .bz2 must still exist, unchanged, in the right place.
while read -r name sum size; do
  if is_bad "$name"; then home=quarantine; else home=dumps; fi
  if [ -f "$home/$name" ]; then
    if [ "$(cksum < "$home/$name")" != "$sum $size" ]; then
      echo "❌ $home/$name was changed; move the dumps, do not modify them (type 'reset')"
      exit 1
    fi
    continue
  fi
  if is_bad "$name"; then
    if [ -f "dumps/$name" ]; then
      n=0; for x in "$bad1" "$bad2"; do [ -f "quarantine/$x" ] && n=$((n + 1)); done
      if [ "$n" -eq 0 ]; then
        echo "❌ quarantine/ is still empty, but some dumps in dumps/ are damaged"
      else
        echo "❌ one damaged dump is in quarantine/, but another damaged one is still in dumps/"
      fi
    else
      echo "❌ a damaged dump is missing from both dumps/ and quarantine/; type 'reset'"
    fi
  else
    if [ -f "quarantine/$name" ]; then
      echo "❌ quarantine/$name passes the integrity test; only damaged dumps belong in quarantine/"
    elif [ -f "restore/${name%.bz2}" ]; then
      echo "❌ dumps/$name is gone; keep the intact .bz2 files in dumps/ (bunzip2 -k or -c leaves them)"
    else
      echo "❌ dumps/$name is gone; type 'reset'"
    fi
  fi
  exit 1
done < .lm-state/bz2.sums

for d in dumps quarantine; do
  extra=$(cd "$d" && ls -A | grep -vxF -f <(awk '{print $1}' "$SANDBOX/.lm-state/bz2.sums") | head -1)
  if [ -n "$extra" ]; then
    echo "❌ $d/$extra should not be there; uncompressed dumps belong in restore/"
    exit 1
  fi
done

for x in "$bad1" "$bad2"; do
  if [ -e "restore/${x%.bz2}" ]; then
    echo "❌ restore/${x%.bz2} comes from a damaged dump (bunzip2 writes the part it could read before failing); remove it"
    exit 1
  fi
done
extra=$(cd restore && ls -A | grep -vxF -f <(awk '{print $1}' "$SANDBOX/.lm-state/sql.sums") | head -1)
if [ -n "$extra" ]; then
  echo "❌ restore/$extra should not be there; restore/ holds only NAME.sql files"
  exit 1
fi
while read -r name sum size; do
  is_bad "$name.bz2" && continue
  if [ ! -f "restore/$name" ]; then
    echo "❌ restore/$name is missing"
    exit 1
  fi
  if [ "$(cksum < "restore/$name")" != "$sum $size" ]; then
    echo "❌ restore/$name is not the complete content of dumps/$name.bz2"
    exit 1
  fi
done < .lm-state/sql.sums
echo "✅ the 2 damaged dumps are quarantined and the 6 intact ones are restored"
exit 0
