#!/bin/bash
# du shows blocks in use, stat the length; cp --sparse=always turns zero blocks
# into holes; tar -S stores holes as holes.
du -k vm/vm1.img vm/vm2.img
for f in vm1.img vm2.img; do echo "$f $(stat -c %s vm/$f) $(du -k vm/$f | cut -f1)"; done > sizes.txt
cp --sparse=always vm/vm2.img vm2-copy.img
tar -S -C vm -cf vm-backup.tar vm1.img
ls -ls vm2-copy.img vm-backup.tar
