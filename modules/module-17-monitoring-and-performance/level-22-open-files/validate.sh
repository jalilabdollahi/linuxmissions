SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/leaker ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s fdleak.env ] || { echo "❌ fdleak.env is missing or empty"; exit 1; }
get() { grep -E "^$1=" fdleak.env | tail -1 | cut -d= -f2- | tr -d ' \t\r'; }
pid=$(get pid); type=$(get type); limit=$(get limit); fds=$(get fds)
for k in pid type limit fds; do
  eval "v=\$$k"
  [ -n "$v" ] || { echo "❌ fdleak.env has no '$k=' line"; exit 1; }
done
case $pid$limit$fds in *[!0-9]*) echo "❌ pid, limit and fds must be plain numbers"; exit 1;; esac
want=$(cat .lm-state/leaker)
if [ "$pid" != "$want" ]; then
  name=$(awk -v p="$pid" '$2==p {print $1}' .lm-state/pids)
  if [ -n "$name" ]; then
    n=$(ls /proc/$pid/fd 2>/dev/null | wc -l)
    soft=$(awk '/^Max open files/ {print $4}' /proc/$pid/limits)
    echo "❌ $name (PID $pid) has $n descriptors open against a limit of $soft: it is not the one in danger"
  else
    echo "❌ PID $pid is not one of the four services"
  fi
  exit 1
fi
real_soft=$(awk '/^Max open files/ {print $4}' /proc/$want/limits)
if [ "$type" != socket ]; then
  echo "❌ type=$type is not what this process leaks; look at where most of its /proc/$want/fd links point"; exit 1
fi
if [ "$limit" != "$real_soft" ]; then
  echo "❌ limit=$limit is not the soft limit that applies to this process (see the 'Max open files' line, soft limit column)"; exit 1
fi
live=$(ls /proc/$want/fd | wc -l)
diff=$((fds - live)); [ "$diff" -lt 0 ] && diff=$((-diff))
if [ "$diff" -gt 5 ]; then
  echo "❌ fds=$fds is too far from the real count of open descriptors (more than 5 off)"; exit 1
fi
echo "✅ PID $want is $live descriptors into a soft limit of $real_soft, all of them leaked sockets"
exit 0
