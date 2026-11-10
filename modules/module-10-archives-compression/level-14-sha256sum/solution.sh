#!/bin/bash
# Verify only what is here, move the FAILED image away, hash the rest from inside isos/.
cd isos
sha256sum -c --ignore-missing SHA256SUMS
mkdir -p ../quarantine
sha256sum -c --ignore-missing SHA256SUMS 2>/dev/null | grep ': FAILED$' | sed 's/: FAILED$//' |
  while IFS= read -r f; do mv -- "$f" ../quarantine/; done
sha256sum *.iso *.img > SHA256SUMS.local
sha256sum -c SHA256SUMS.local
cd ..
