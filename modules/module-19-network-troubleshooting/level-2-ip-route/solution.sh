#!/bin/bash
# For each destination keep the covering route with the longest prefix.
python3 - <<'PY' > answers.tsv
import ipaddress
routes = []
for line in open('routes.txt'):
    w = line.split()
    net = ipaddress.ip_network('0.0.0.0/0' if w[0] == 'default' else w[0])
    gw = w[w.index('via') + 1] if 'via' in w else 'direct'
    routes.append((net, gw, w[w.index('dev') + 1]))
for d in open('destinations.txt').read().split():
    ip = ipaddress.ip_address(d)
    net, gw, dev = max((r for r in routes if ip in r[0]), key=lambda r: r[0].prefixlen)
    print(d, gw, dev, sep='\t')
PY
cat answers.tsv
