#!/bin/bash
# Three Exports, One Report: 60 hosts with random cpu/mem values in three
# parallel files. cpu.txt has Windows (CRLF) line endings, so a plain paste
# puts a \r in the middle of every row. Around the threshold: 90.0 counts,
# 89.9 does not.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM" 'BEGIN {
  srand(seed)
  split("web api db cache queue search mail lb", role, " ")
  n = 0
  for (r = 1; r <= 8; r++) {
    k = 5 + int(rand() * 5)
    for (i = 1; i <= k && n < 60; i++) host[++n] = sprintf("%s-%02d", role[r], i)
  }
  while (n < 60) { n++; host[n] = sprintf("worker-%02d", n) }
  # Shuffle so the file is not grouped by role.
  for (i = n; i > 1; i--) { j = 1 + int(rand() * i); t = host[i]; host[i] = host[j]; host[j] = t }
  for (i = 1; i <= n; i++) {
    c = (rand() < 0.15) ? 90 + rand() * 9.9 : 3 + rand() * 85
    cpu[i] = sprintf("%.1f", c); mem[i] = sprintf("%.1f", 10 + rand() * 89)
  }
  cpu[1 + int(rand() * 20)] = "90.0"; cpu[21 + int(rand() * 20)] = "89.9"
  for (i = 1; i <= n; i++) {
    print host[i] > "hosts.txt"
    printf "%s\r\n", cpu[i] > "cpu.txt"
    print mem[i] > "mem.txt"
    printf "%s\t%s\t%s\n", host[i], cpu[i], mem[i] > ".lm-state/report"
    if (cpu[i] + 0 >= 90) sel = sel (sel == "" ? "" : ",") host[i]
  }
  print sel > ".lm-state/limit"
}'
cksum hosts.txt cpu.txt mem.txt | awk '{ print $1, $2 }' > .lm-state/inputs.sum
