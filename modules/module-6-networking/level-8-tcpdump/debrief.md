# Packet Sniff

## Why it works
A SYN scan sends one SYN to each port and reads the answer: SYN-ACK
(`Flags [S.]`) means a program is listening, RST-ACK (`[R.]`) means closed.
Filtering with `tcp[tcpflags] == tcp-syn` keeps only first packets of
connection attempts; counting *distinct destination ports* per source separates
the scanner (45 ports) from the SSH password guesser, which sent even more SYNs
but always to port 22. The SYN-ACKs that web-03 sent back to the scanner list
exactly the ports the attacker now knows are open.

## Common mistakes
- Counting SYN packets per source: 198.51.100.23 wins that, but it is a
  brute-force attempt on one port, a different problem.
- Forgetting `-nn`: tcpdump then prints service names (`https`, `ssh`) and
  tries reverse DNS, which is slow and makes the fields harder to parse.
- Using `'tcp[tcpflags] & tcp-syn != 0'` in the first step: that also matches
  every SYN-ACK, so web-03 shows up as a "scanner" too.

## Learn next
Capture yourself (needs root): `sudo tcpdump -i any -nn -w out.pcap
'tcp port 443'`, stop with Ctrl-C, then read it with `-r`. `tcpdump -A` prints
payloads as text, and `tshark -r capture.pcap -q -z conv,tcp` summarises
conversations. On the defending side, `ss -tln` on web-03 shows the same open
ports from the inside.
