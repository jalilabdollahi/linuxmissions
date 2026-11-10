# Who Else Is Answering?

## Why it works
The neighbour table maps each IP to the MAC that last answered ARP for it. A
legitimate host keeps its MAC; an address that flips back and forth between
two MACs means two devices claim it, and every flip sends traffic for that
IP to the wrong box for a while: the "drops for a minute, then recovers"
symptom. You lower-cased the MACs (the 09:05 capture came from a tool that
prints upper case), skipped FAILED/INCOMPLETE lines (no `lladdr`, so field 5
is not a MAC), and kept only the address with two distinct MACs. The first
three bytes of a MAC are the vendor's OUI, which told facilities to look for
a small board or USB adapter rather than a server.

## Common mistakes
- Comparing MACs as text: `AA:BB` and `aa:bb` are the same address, and
  without `tolower` every host seems to change MAC at 09:05.
- Treating `FAILED` as a MAC change: it only means the last ARP request got
  no answer. Awk's `$5` on such a line is not an address.
- Searching oui.txt for `dc:a6:32`: the IEEE list writes `DC-A6-32` (hex) or
  `DCA632` (base 16).

## Learn next
On a live host, `ip -s neigh` shows how long ago each entry was used and
confirmed, and `arping -D -I eth0.30 10.30.0.1` sends duplicate address
detection probes: two different replies prove the conflict. `arpwatch`
logs "flip flop" events exactly like this one.
