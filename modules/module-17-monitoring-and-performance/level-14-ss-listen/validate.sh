SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/answer ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
if [ ! -s port.txt ]; then echo "❌ port.txt is missing or empty"; exit 1; fi
got=$(tr -d ' \t\r\n' < port.txt)
case $got in
  ''|*[!0-9]*) echo "❌ port.txt should contain only a port number"; exit 1;;
esac
want=$(cat .lm-state/answer)
if [ "$got" = "$want" ]; then
  echo "✅ port $want is the listener whose accept queue is full"
  exit 0
fi
if ss -ltn "sport = :$got" | tail -n +2 | grep -q .; then
  read -r rq sq < <(ss -ltn "sport = :$got" | awk 'NR==2 {print $2, $3}')
  echo "❌ port $got is listening, but its accept queue is not full (Recv-Q $rq of backlog $sq)"
else
  echo "❌ nothing listens on port $got in this sandbox"
fi
exit 1
