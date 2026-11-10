#!/bin/bash
awk 'BEGIN{OFS="\t"} /^#/||NF==0 {print;next} $2=="/"{$1="LABEL=cloudimg-rootfs"} $2=="/boot/efi"{$1="LABEL=UEFI"} $2=="/home"{$1="LABEL=home"; sub(/noatme/,"noatime",$4)} $2=="/mnt/backup"{$1="LABEL=usb-backup"; $3="xfs"; $4="defaults,nofail"} {print}' sysroot/etc/fstab > fstab.new && cp fstab.new sysroot/etc/fstab && rm fstab.new
mkdir -p sysroot/mnt/backup
./fstab-lint
