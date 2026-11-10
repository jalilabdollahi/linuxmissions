#!/bin/bash
# rogue.txt = "port pid exe" of the rogue listener (exe as /proc/PID/exe says),
# the rogue is stopped, every approved listener is still up.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
read -r rport rpid rexe < .lm-state/expected
alive() {   # running and not a zombie
  local st; st=$(sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null | cut -c1)
  [ -n "$st" ] && [ "$st" != Z ] && [ "$st" != X ]
}
listening() { ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$1\$"; }
for p in $(cat .lm-state/approved_ports); do
  listening "$p" || { echo "❌ an approved service (port $p) is no longer listening: you stopped the wrong process, type 'reset'"; exit 1; }
done
[ -f rogue.txt ] || { echo "❌ rogue.txt does not exist yet"; exit 1; }
got=$(tr -d '\r' < rogue.txt | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | grep -v '^$')
[ -n "$got" ] || { echo "❌ rogue.txt is empty"; exit 1; }
if [ "$(wc -l <<< "$got")" -ne 1 ]; then echo "❌ rogue.txt must contain exactly one line"; exit 1; fi
if [ "$got" != "$rport $rpid $rexe" ]; then
  read -r gp gpid gexe _ <<< "$got"
  if [ "$gp" != "$rport" ]; then
    echo "❌ port $gp is not the unapproved listener (compare every listening port with approved.txt, IPv4 and IPv6)"
  elif [ "$gpid" != "$rpid" ]; then
    echo "❌ the pid in rogue.txt is not the process listening on port $gp"
  else
    echo "❌ the exe is not what /proc/$rpid/exe points to (a process name or argv[0] can say anything)"
  fi
  exit 1
fi
if alive "$rpid" || listening "$rport"; then
  echo "❌ the rogue listener is recorded correctly but still running"; exit 1
fi
echo "✅ the rogue listener on port $rport was identified and stopped; approved services still up"
exit 0
