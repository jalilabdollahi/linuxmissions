#!/bin/bash
# host_net.txt = `pid comm` of every process with its own PID namespace but the host's
# network namespace (host = the namespaces PID 1 is in), ascending by PID.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -s capture/ps.txt ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f host_net.txt ] || { echo "❌ host_net.txt does not exist yet"; exit 1; }
got=$(tr -d '\r' < host_net.txt | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | grep -v '^$')
want=$(cat .lm-state/expected)
[ -n "$got" ] || { echo "❌ host_net.txt is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ $(wc -l <<< "$want" | tr -d ' ') processes with their own PID namespace on the host network found"; exit 0
fi
if grep -qvE '^[0-9]+ [^ ]+$' <<< "$got"; then
  echo "❌ every line must be 'pid comm', for example: 1234 nginx"; exit 1
fi
extra=$(comm -13 <(sort <<< "$want") <(sort <<< "$got") | head -1)
if [ -n "$extra" ]; then
  p=${extra%% *}
  row=$(awk -v p="$p" '$1 == p' capture/ps.txt)
  if [ -z "$row" ]; then echo "❌ PID $p is not in capture/ps.txt"
  else
    read -r _ _ pidns netns _ <<< "$row"
    hostpid=$(awk '$1 == 1 {print $3}' capture/ps.txt)
    if [ "$pidns" = "$hostpid" ]; then
      echo "❌ PID $p is in the host's PID namespace, so it does not have its own"
    else
      echo "❌ PID $p has its own PID namespace but not the host's network namespace (host = the namespaces of PID 1)"
    fi
  fi
  exit 1
fi
if [ "$(sort <<< "$got")" = "$(sort <<< "$want")" ]; then
  echo "❌ the right processes, but not in ascending PID order (or duplicated)"; exit 1
fi
echo "❌ $(comm -23 <(sort <<< "$want") <(sort <<< "$got") | wc -l | tr -d ' ') matching process(es) missing from host_net.txt"
exit 1
