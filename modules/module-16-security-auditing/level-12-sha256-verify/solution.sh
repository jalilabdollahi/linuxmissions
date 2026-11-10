#!/bin/bash
# Plain `sha256sum -c --ignore-missing` only covers part of the list: normalise a copy first.
cd release
cat -A SHA256SUMS | cut -c1-100
sed -E -e 's/\r$//' -e 's/^SHA256 \((.*)\) = ([0-9a-f]{64})$/\2  \1/' -e 's/^([0-9a-f]{64}) +\*?(dist\/)?/\1  /' SHA256SUMS > SHA256SUMS.fixed
sha256sum -c --ignore-missing SHA256SUMS.fixed > ../verify.log 2>&1
cd ..
cat verify.log
grep ': FAILED' verify.log | cut -d: -f1 | while IFS= read -r f; do mv "release/$f" quarantine/; done
ls quarantine
