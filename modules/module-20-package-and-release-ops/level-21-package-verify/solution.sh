#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
dpkg -V > verify.txt
awk 'NF == 3 && $2 == "c" { print $3 }' verify.txt | sort > conffiles-changed.txt
awk 'NF == 2 { print $2 }' verify.txt | sort > tampered.txt
for f in $(cat tampered.txt); do
  pkg=$(dpkg -S "$f" | cut -d: -f1)
  deb=$(ls repos/main/pool/main/*/"$pkg"/"${pkg}"_*.deb)
  dpkg-deb --fsys-tarfile "$deb" | tar -xOf - ".$f" > "rootfs$f"
done
dpkg -V
