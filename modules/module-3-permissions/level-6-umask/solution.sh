#!/bin/bash
sed -i.bak 's/^umask 000$/umask 027/' start_app.sh
rm -f start_app.sh.bak
rm -rf data
./start_app.sh
