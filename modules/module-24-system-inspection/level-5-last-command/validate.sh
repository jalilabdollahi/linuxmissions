#!/bin/bash
# reboots.txt = number of October 2026 reboots; crash_users.txt = users whose
# sessions ended in "crash" at an October reboot (sorted, unique).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/reboots ] && [ -s .lm-state/crash_users ] && [ -s capture/wtmp ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f reboots.txt ] || { echo "❌ reboots.txt does not exist yet"; exit 1; }
[ -f crash_users.txt ] || { echo "❌ crash_users.txt does not exist yet"; exit 1; }
want_n=$(cat .lm-state/reboots)
got_n=$(tr -d '[:space:]' < reboots.txt)
case $got_n in
  ''|*[!0-9]*) echo "❌ reboots.txt must contain only a number"; exit 1;;
esac
if [ "$got_n" != "$want_n" ]; then
  total=$(last -x -f capture/wtmp reboot 2>/dev/null | grep -c '^reboot')
  if [ "$got_n" = "$total" ]; then
    echo "❌ reboots.txt counts every reboot in the file, not just the ones in October"
  else
    echo "❌ reboots.txt says $got_n, which is not the number of October reboots in the capture"
  fi
  exit 1
fi
want=$(cat .lm-state/crash_users)
got=$(tr -d '\r' < crash_users.txt | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
[ -n "$got" ] || { echo "❌ crash_users.txt is empty"; exit 1; }
if [ "$got" != "$want" ]; then
  if [ "$(echo "$got" | sort -u)" = "$want" ]; then
    echo "❌ crash_users.txt has the right users but is not sorted, or lists someone twice"
  else
    extra=$(comm -13 <(echo "$want") <(echo "$got" | sort -u) | head -1)
    if [ -n "$extra" ]; then
      echo "❌ $extra is listed, but no session of theirs ended in a crash during an October reboot"
    else
      echo "❌ crash_users.txt is missing $(comm -23 <(echo "$want") <(echo "$got" | sort -u) | wc -l | tr -d ' ') user(s) whose sessions ended in a crash"
    fi
  fi
  exit 1
fi
echo "✅ $want_n reboots in October, $(echo "$want" | wc -l | tr -d ' ') users hit by crashes"
exit 0
