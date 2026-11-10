#!/bin/bash
# 1. For every source of pure SYN packets, count the distinct destination ports.
tcpdump -nn -r capture.pcap 'tcp[tcpflags] == tcp-syn' 2>/dev/null \
  | awk '{ split($3, s, "."); n = split($5, d, "."); sub(":", "", d[n]); print s[1] "." s[2] "." s[3] "." s[4], d[n] }' \
  | sort -u | awk '{ print $1 }' | uniq -c | sort -nr | head -1 | awk '{ print $2 }' > scanner.txt
scanner="$(cat scanner.txt)"
# 2. SYN-ACKs from web-03 to the scanner: the source port is an open port.
tcpdump -nn -r capture.pcap "src host 10.20.4.17 and dst host $scanner and tcp[tcpflags] == (tcp-syn|tcp-ack)" 2>/dev/null \
  | awk '{ n = split($3, a, "."); print a[n] }' | sort -n > open_ports.txt
cat scanner.txt open_ports.txt
