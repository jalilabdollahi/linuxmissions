#!/bin/bash
# Stage the tree, -L (like tar -h) follows the listed links, then pack, split and sum.
rm -rf stage; mkdir -p stage/dr-bundle/files out
rsync -aL --files-from=bundle.list box/ stage/dr-bundle/files/
cp box/etc/fstab stage/dr-bundle/fstab
sfdisk -d disk.img > stage/dr-bundle/disk.sfdisk
( cd stage/dr-bundle && find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256 )
tar -czf stage/dr-bundle.tgz -C stage dr-bundle
split -b 20000000 stage/dr-bundle.tgz out/dr-bundle.tgz.part-
( cd out && sha256sum dr-bundle.tgz.part-* > SHA256SUMS )
ls -l out
