#!/bin/bash
pid=$(pgrep -f 'indexer\.py')
{
  echo "soft=$(awk '/Max open files/ {print $4}' /proc/$pid/limits)"
  echo "hard=$(awk '/Max open files/ {print $5}' /proc/$pid/limits)"
  echo "open=$(ls /proc/$pid/fd | wc -l)"
} > limits.txt
cat limits.txt
cat > sysroot/etc/systemd/system/indexer.service.d/override.conf <<'T'
[Service]
LimitNOFILE=65536
T
