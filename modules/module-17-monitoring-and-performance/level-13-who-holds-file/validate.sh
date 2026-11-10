SANDBOX="$1"
cd "$SANDBOX" || exit 1
SANDBOX=$(pwd -P)
if [ ! -s .lm-state/holders ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
if [ ! -s holders.txt ]; then echo "❌ holders.txt is missing or empty"; exit 1; fi
alive() { [ -r /proc/$1/status ] && [ "$(ps -o stat= -p "$1" 2>/dev/null | cut -c1)" != Z ]; }
while read -r name pid; do
  alive "$pid" || { echo "❌ $name (PID $pid) is gone; the task is to find the holders, not to stop them"; exit 1; }
done < .lm-state/pids
# normalise: trailing slashes off, one "PID PATH" per line
norm() { awk 'NF==2 {p=$2; while (length(p)>1 && substr(p,length(p),1)=="/") p=substr(p,1,length(p)-1); print $1, p} NF!=2 && NF>0 {print "BAD", $0}' "$1" | sort -u; }
norm holders.txt > .lm-state/got
if grep -q '^BAD' .lm-state/got; then
  echo "❌ holders.txt must have exactly two fields per line: PID PATH (a line like '$(grep -m1 '^BAD' .lm-state/got | cut -c5-)' does not)"; exit 1
fi
norm .lm-state/holders > .lm-state/want
missing=$(comm -13 .lm-state/got .lm-state/want | head -1)
extra=$(comm -23 .lm-state/got .lm-state/want | head -1)
if [ -n "$extra" ]; then
  set -- $extra
  if grep -q "^$1 " .lm-state/want; then
    echo "❌ PID $1 is a real holder, but the path '$2' is not what it holds (give the file it has open, or the directory it sits in)"
  else
    echo "❌ PID $1 does not use data/ (it only looks related: another directory with a similar name, or your own shell)"
  fi
  exit 1
fi
if [ -n "$missing" ]; then
  n=$(comm -13 .lm-state/got .lm-state/want | wc -l)
  echo "❌ $n holder(s) still missing from holders.txt; one holds a file open, another has no open file at all but still blocks the unmount"
  exit 1
fi
echo "✅ all three holders found: the writer, the reader and the process that merely sits in data/queue"
exit 0
