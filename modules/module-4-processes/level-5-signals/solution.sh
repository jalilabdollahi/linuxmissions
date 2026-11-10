#!/bin/bash
sed -i.bak 's/^log_level=info$/log_level=debug/' listener.conf
rm -f listener.conf.bak
kill -HUP "$(cat listener.pid)"
sleep 1.5
