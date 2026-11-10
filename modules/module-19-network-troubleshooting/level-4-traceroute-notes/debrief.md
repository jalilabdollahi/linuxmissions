# Where Does the Path Break?

## Why it works
traceroute sends probes with growing TTLs and lists who sends back "time
exceeded". A router in the middle that stays silent while later hops answer is
only refusing (or rate-limiting) those ICMP replies: the packets still pass
through it. The break is after the last hop that answers, when everything
behind it stays silent; here that was the provider's edge firewall, which
answers itself but doesn't forward to the API. A jump in latency belongs to
a link, so compare averages of answering hops: one slow probe or a high Wrst
is a busy router CPU, a sustained +60-100 ms is a long-distance link (an ocean
crossing).

## Common mistakes
- Reporting the first `* * *` as the break, or reading mtr's 100 % Loss on a
  middle hop as packet loss for the whole path. Loss only matters when it
  continues to the hops after it.
- Comparing with a silent hop's 0.0 Avg, or with a single probe.

## Learn next
`mtr -n --report-wide -c 100 HOST` gives a report you can paste into a ticket;
`traceroute -T -p 443 HOST` (TCP SYN probes, needs root) or `tracepath` get past
firewalls that drop UDP or ICMP probes, and show where a path to a specific
port is filtered.
