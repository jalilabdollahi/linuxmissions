#!/bin/bash
# gpgv exits 0 only for a good signature from a key in the given keyring.
: > report.txt
for d in mirrors/*; do
  m=${d##*/}
  if gpgv --keyring ./vendor.gpg "$d/agent-2.3.1.tar.gz.sig" "$d/agent-2.3.1.tar.gz" 2>/dev/null; then
    echo "$m good" >> report.txt
    mv "$d/agent-2.3.1.tar.gz" verified/
  else
    echo "$m bad" >> report.txt
    rm -f "$d/agent-2.3.1.tar.gz"
  fi
done
cat report.txt
ls -l verified
