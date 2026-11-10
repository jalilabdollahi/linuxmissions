#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkdir -p etc/myapp/v1 etc/myapp/v2 etc/myapp/v3-rc
printf 'version=1\nworkers=2\ncache=off\n' > etc/myapp/v1/config.conf
printf 'version=2\nworkers=8\ncache=on\n' > etc/myapp/v2/config.conf
printf 'version=3-rc\nworkers=16\ncache=experimental\n' > etc/myapp/v3-rc/config.conf

# The current link, relative, pointing at v1
ln -s v1/config.conf etc/myapp/active.conf
