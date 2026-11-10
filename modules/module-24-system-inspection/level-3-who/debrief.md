# Who Was On the Jump Host?

## Why it works
`who` is just a reader for the utmp file; giving it a filename makes it
describe a different machine, here the snapshot. Each remote session ends
with the source host in parentheses. Anchoring the test with `^10\.` means
"the first octet is exactly 10", which is what 10.0.0.0/8 says.

## Common mistakes
- Running plain `who`: it shows the live system, which has no sessions.
- Matching `10.` anywhere: 110.4.5.6 and 210.1.2.3 are outside addresses.
- Forgetting that 172.16.0.0/12 and 192.168.0.0/16 are private too, but not
  part of 10.0.0.0/8, so they belong in the list.

## Next step
`who -a` adds boot time and dead processes, `last -f` reads the history file
(wtmp) in the same way, and `utmpdump FILE` prints every raw record.
