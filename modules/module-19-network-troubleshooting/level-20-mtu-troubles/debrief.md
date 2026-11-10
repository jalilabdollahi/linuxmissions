# Too Big to Arrive

## Why it works
With the don't-fragment bit set, a packet that is too big for some link
can't be split; the router drops it and should send back ICMP
"fragmentation needed" with its MTU. When a firewall swallows that ICMP
message, the sender never learns and keeps sending big packets into
nothing: a PMTU black hole. Small exchanges (ssh keystrokes, a login page)
fit and work; bulk transfers fill full-size packets and hang. Probing with
DF set and a binary search found the largest packet that survives in about
eight tries. `ping -s` sets the ICMP *payload*; the IP packet adds 20 bytes
of IP and 8 of ICMP header, so the MTU is payload + 28. Setting wg0's MTU to
that value makes the kernel build packets that fit.

## Common mistakes
- Writing the payload size as the MTU: 28 bytes too small. It works, but
  wastes a little on every packet. Too large an MTU is the real problem.
- Probing without DF (`-M do`): the kernel fragments, everything "works",
  and you learn nothing.
- Trying every size from the top: at one or two seconds per lost probe that
  takes minutes, and real routers rate-limit ICMP, so fast scans lie.

## Learn next
`tracepath HOST` discovers the PMTU hop by hop when the ICMP messages do
arrive. `ip route get HOST` shows a cached PMTU (`mtu 1400 expires ...`).
When you can't fix the path, MSS clamping on the router
(`iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS
--clamp-mss-to-pmtu`) keeps TCP segments small enough.
