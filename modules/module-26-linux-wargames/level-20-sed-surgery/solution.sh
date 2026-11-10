#!/bin/bash
sed -i.bak -E '/^\[tls\]/,/^\[/{s/^([[:space:]]*ssl_protocols[[:space:]]*=[[:space:]]*)[^[:cntrl:]]*/\1TLSv1.2 TLSv1.3/}; /^\[upstream\]/,/^\[/{s/^([[:space:]]*port[[:space:]]*=[[:space:]]*)8080\b/\18443/}' conf/*.conf
