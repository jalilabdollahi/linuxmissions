#!/bin/bash
# Join the 14 parts in numeric order (the brace list, not the glob), verify, extract.
ls backup.part* | sort -V
cat backup.part{1..14} > backup.tar.gz
sha256sum -c backup.tar.gz.sha256
mkdir -p restored
tar -xzf backup.tar.gz -C restored
ls restored/shop
