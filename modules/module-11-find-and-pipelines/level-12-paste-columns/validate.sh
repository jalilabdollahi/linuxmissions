#!/bin/bash
# report.tsv = host<TAB>cpu<TAB>mem per line, no \r; limit.txt = one line of
# comma-joined hosts with cpu >= 90.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/report ] || [ ! -s .lm-state/limit ] || [ ! -s .lm-state/inputs.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ "$(cksum hosts.txt cpu.txt mem.txt 2>/dev/null | awk '{ print $1, $2 }')" != "$(cat .lm-state/inputs.sum)" ]; then
  echo "❌ hosts.txt, cpu.txt or mem.txt was changed; leave the exports as they are (type 'reset')"
  exit 1
fi

if [ ! -f report.tsv ]; then
  echo "❌ report.tsv does not exist yet"
  exit 1
fi
if ! cmp -s report.tsv .lm-state/report; then
  if [ ! -s report.tsv ]; then
    echo "❌ report.tsv is empty"
  elif grep -q "$(printf '\r')" report.tsv; then
    echo "❌ report.tsv contains carriage returns (\\r); one of the exports has Windows line endings (look at it with cat -A or od -c)"
  elif [ "$(wc -l < report.tsv | tr -d ' ')" != 60 ]; then
    echo "❌ report.tsv has $(wc -l < report.tsv | tr -d ' ') lines; there are 60 hosts"
  elif awk -F'\t' 'NF != 3 { bad = 1 } END { exit !bad }' report.tsv; then
    echo "❌ every line of report.tsv must be host, cpu, mem separated by single tabs"
  elif [ "$(cut -f1 report.tsv)" != "$(cat hosts.txt)" ]; then
    echo "❌ the first column of report.tsv must be the hosts, in the order of hosts.txt"
  else
    echo "❌ report.tsv has the hosts right, but the cpu or mem column does not match the exports (cpu second, mem third)"
  fi
  exit 1
fi

if [ ! -f limit.txt ]; then
  echo "❌ limit.txt does not exist yet"
  exit 1
fi
want=$(cat .lm-state/limit)
lines=$(grep -c '' limit.txt)
got=$(tr -d '\r' < limit.txt | head -1)
if [ "$lines" -gt 1 ]; then
  echo "❌ limit.txt has $lines lines; ansible --limit wants all hosts on one line"
elif [ "$got" = "$want" ]; then
  echo "✅ report.tsv has all 60 hosts in clean tab-separated rows and limit.txt lists the $(printf '%s\n' "$want" | tr ',' '\n' | wc -l | tr -d ' ') saturated hosts"
  exit 0
elif [ "${got%,}" = "$want" ]; then
  echo "❌ limit.txt ends with a comma"
elif printf '%s' "$got" | grep -q '[[:space:]]'; then
  echo "❌ limit.txt contains spaces or tabs; only host names and commas"
else
  n_got=$(printf '%s\n' "$got" | tr ',' '\n' | grep -c .)
  n_want=$(printf '%s\n' "$want" | tr ',' '\n' | grep -c .)
  if [ "$n_got" -ne "$n_want" ]; then
    echo "❌ limit.txt names $n_got host(s), but $n_want have a cpu of 90 or more"
  else
    echo "❌ limit.txt names the right number of hosts, but not the right ones in report order"
  fi
fi
exit 1
