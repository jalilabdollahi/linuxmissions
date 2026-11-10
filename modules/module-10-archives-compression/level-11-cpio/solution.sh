#!/bin/bash
file initrd.img
gzip -dc initrd.img | cpio -t | grep '\.ko$' | sed 's|.*/||' > modules.txt
cd initrd-root && gzip -dc ../initrd.img | cpio -idmv 'etc/*'
cd ..
ls -R initrd-root
