#!/bin/bash
# queue_sorted.txt = queue.txt grouped by priority P1..P4, arrival order kept.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/queue.sum ] || [ "$(cksum < queue.txt 2>/dev/null)" != "$(cat .lm-state/queue.sum)" ]; then
  echo "❌ queue.txt was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f queue_sorted.txt ]; then
  echo "❌ queue_sorted.txt does not exist yet"
  exit 1
fi

EXPECTED=$(for p in P1 P2 P3 P4; do awk -v p="$p" '$2 == p' queue.txt; done)
GOT=$(tr -d '\r' < queue_sorted.txt | sed '/^[[:space:]]*$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ queue_sorted.txt: $(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ') tickets by priority, first come first served within each"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ queue_sorted.txt is empty"; exit 1; fi
if [ "$(printf '%s\n' "$GOT" | sort)" != "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  echo "❌ queue_sorted.txt must contain exactly the lines of queue.txt, each once and unchanged"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | awk '{ print $2 }' | uniq)" != "$(printf 'P1\nP2\nP3\nP4')" ]; then
  echo "❌ the tickets are not grouped by priority from P1 down to P4"
  exit 1
fi
# Priorities are right, so the order inside a priority is wrong. Say how.
for p in P1 P2 P3 P4; do
  g=$(printf '%s\n' "$GOT" | awk -v p="$p" '$2 == p')
  w=$(printf '%s\n' "$EXPECTED" | awk -v p="$p" '$2 == p')
  if [ "$g" != "$w" ]; then
    if [ "$g" = "$(printf '%s\n' "$w" | sort)" ]; then
      echo "❌ the $p tickets are ordered by ticket id, not by arrival: when keys are equal, sort compares the whole line unless told to keep the input order"
    elif [ "$g" = "$(printf '%s\n' "$w" | sort -k2)" ] || [ "$g" = "$(printf '%s\n' "$w" | sort -k3)" ]; then
      echo "❌ the $p tickets are ordered by customer/subject, not by arrival: a key written -k2 runs to the end of the line"
    else
      echo "❌ the $p tickets are not in the order they arrived in queue.txt"
    fi
    exit 1
  fi
done
echo "❌ queue_sorted.txt is not in the expected order"
exit 1
