#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
I=repos/acme/dists/noble/InRelease
for k in keyrings/*.gpg; do
  if gpgv --keyring "./$k" "$I" >/dev/null 2>&1; then good=$k; fi
done
echo "verifies: $good"
sed -i "s|^deb |deb [signed-by=$SANDBOX/$good] |" rootfs/etc/apt/sources.list.d/acme.list
cat rootfs/etc/apt/sources.list.d/acme.list
apt-get update
