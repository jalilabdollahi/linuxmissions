#!/bin/bash
for i in $(seq 1 12); do
  if [ -f incoming/resent/part.$i ]; then cat incoming/resent/part.$i; else cat incoming/part.$i; fi
done > dataset.tar.gz
sha256sum -c --ignore-missing SHA256SUMS
mkdir -p restored
tar -xzf dataset.tar.gz -C restored dataset/reports
(cd restored && grep ' dataset/reports/' ../SHA256SUMS | sha256sum -c --quiet)
