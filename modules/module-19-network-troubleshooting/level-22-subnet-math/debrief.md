# Covered Twice

## Why it works
A CIDR entry is a network address plus a prefix length; only the first
`prefix` bits matter. Python's `ipaddress` turned every line into a real
network (`strict=False` for entries like `10.1.2.77/24`, which firewalls
quietly treat as `10.1.2.0/24`, and a bare address as a /32) and answered
containment with `subnet_of()` and `in`. Comparing by value also made the
kernel's fully written-out IPv6 addresses (`2001:0db8:...:0b2d`) match the
compressed `2001:db8:...::/64` in the list.

## Common mistakes
- String matching: `grep 10.1.2.` matches 10.1.2.0/24 but also 10.1.20.0/24,
  and it can't tell that a /30 sits inside a /21.
- `ip_network("10.1.2.77/24")` without `strict=False` raises "has host bits
  set"; deleting such lines loses real entries.
- Marking both copies of a duplicated network as redundant: remove one and
  the other must stay.
- Reading DST= instead of SRC=, or dropping IPv6 lines because they look
  different.

## Learn next
`ipcalc` / `sipcalc` print network, broadcast and host range for one entry.
`python3 -c 'import ipaddress as i; print(list(i.collapse_addresses(map(i.ip_network, ["10.0.0.0/24","10.0.1.0/24"]))))'`
merges adjacent networks into the shortest list, which is the next step of
this cleanup. On Linux, `ipset` with `hash:net` stores such lists for
iptables/nftables efficiently.
