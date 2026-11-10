#!/bin/bash
D=$(ls -d rescue/usr/lib/*/)
N=$(for f in rescue/usr/bin/jq $D*.so*; do readelf -d $f 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'; done | sort -u | while read n; do [ -e $D$n ] || echo $n; done | head -n1); echo "missing: $N"
P=$(for p in pkgcache/*.deb; do dpkg-deb -c $p | grep "/$N\." >/dev/null && echo $p; done); echo "package: $P"
mkdir -p unpacked && dpkg-deb -x $P unpacked
F=$(ls unpacked/usr/lib/*/$N.*); cp $F $D; ln -s $(basename $F) $D$N
rescue/ld.so --library-path "$PWD/$D" rescue/usr/bin/jq --version
