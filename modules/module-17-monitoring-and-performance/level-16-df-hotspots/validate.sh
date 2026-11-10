SANDBOX="$1"
cd "$SANDBOX" || exit 1
SANDBOX=$(pwd -P)
if [ ! -s .lm-state/answer ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s culprit.txt ] || { echo "❌ culprit.txt is missing or empty"; exit 1; }
read -r want_mp want_dir < .lm-state/answer
read -r mp dir extra < culprit.txt
if [ -z "$mp" ] || [ -z "$dir" ] || [ -n "$extra" ]; then
  echo "❌ culprit.txt must be one line with exactly two fields: MOUNTPOINT DIRECTORY"; exit 1
fi
norm() { d=${1#"$SANDBOX"/}; d=${d#./}; while [ "${d%/}" != "$d" ]; do d=${d%/}; done; echo "$d"; }
if [ "$mp" != "$want_mp" ]; then
  if grep -q " $mp\$" captured/df-i.txt; then
    ipct=$(awk -v m="$mp" '$6==m {print $5}' captured/df-i.txt)
    echo "❌ $mp is not the filesystem that is out of space (its inode use is $ipct)"
  else
    echo "❌ $mp does not appear in the captured df output"
  fi
  exit 1
fi
d=$(norm "$dir")
if [ "$d" != "$want_dir" ]; then
  if [ -d "$d" ]; then
    n=$(find "$d" -maxdepth 1 -type f | wc -l)
    echo "❌ the mount point is right, but $d holds only $n files directly; look for the directory with the most files, not the most bytes"
  else
    echo "❌ the mount point is right, but '$dir' is not a directory in spool/"
  fi
  exit 1
fi
echo "✅ $want_mp is out of inodes, and $want_dir holds the flood of tiny files"
exit 0
