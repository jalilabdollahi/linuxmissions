#!/bin/bash
# New account: home from /etc/skel, bash, full name, two supplementary groups.
./useradd -m -s /bin/bash -c "Dana Kim" -G dev,docker dana
# Existing account: -a (append) keeps sam's other groups.
./usermod -aG docker sam
./id dana
./id sam
