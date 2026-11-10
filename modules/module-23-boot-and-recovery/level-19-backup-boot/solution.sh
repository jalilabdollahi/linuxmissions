#!/bin/bash
for t in $(ls -r backups/*.tar.gz); do gzip -t $t 2>/dev/null || { echo "skip $t (damaged)"; continue; }; rm -rf sysroot/boot/efi/EFI; tar -xzf $t -C sysroot ./boot/efi/EFI; (cd sysroot/boot/efi && sha256sum -c --quiet ../../../EFI.SHA256SUMS) && { echo "restored from $t"; break; }; done
(cd sysroot/boot/efi && sha256sum -c ../../../EFI.SHA256SUMS); find sysroot/boot/efi -type f | head
