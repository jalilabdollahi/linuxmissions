SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/answer ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s culprit.txt ] || { echo "❌ culprit.txt is missing or empty"; exit 1; }
got=$(tr -d ' \t\r\n' < culprit.txt)
case $got in ''|*[!0-9]*) echo "❌ culprit.txt should contain only a PID (a number)"; exit 1;; esac
want=$(cat .lm-state/answer)
if [ "$got" = "$want" ]; then
  echo "✅ PID $want is the parent spawning the CPU-heavy children"
  exit 0
fi
name=$(awk -v p="$got" '$2==p {print $1}' .lm-state/pids)
if [ -n "$name" ] && [ "$name" = metrics-agent ]; then
  echo "❌ PID $got is a long-running process, but it uses only a small, steady amount of CPU"
elif [ -n "$name" ]; then
  echo "❌ PID $got also spawns short-lived children, but they use almost no CPU; look at which children actually burn CPU"
elif [ -r "/proc/$got/stat" ]; then
  echo "❌ PID $got exists, but it is a short-lived child or something unrelated; the culprit is the long-running process that starts them (the parent)"
else
  echo "❌ PID $got does not exist any more: you caught one of the short-lived children; write the PID of their parent instead"
fi
exit 1
