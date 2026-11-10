#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
pricer --check release-1.5/pricer.conf
sed -i -E 's/^(markup_pct *= *[0-9]+)%/\1/' release-1.5/pricer.conf
pricer --check release-1.5/pricer.conf
cp release-1.5/pricer.conf etc/pricer/pricer.conf
kill -HUP "$(cat run/pricer.pid)"
sleep 0.5
curl -s "http://127.0.0.1:$(sed -n 's/^listen_port *= *//p' etc/pricer/pricer.conf)/version"
