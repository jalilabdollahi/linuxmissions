#!/bin/bash
cd sysroot
run=$(cat ../uname-r.txt)
ls boot lib/modules
new=$(ls lib/modules | sort -V | tail -n 1)
echo "running=$run newest=$new"
for v in $(ls lib/modules); do
  [ "$v" = "$run" ] || [ "$v" = "$new" ] && continue
  rm -v boot/*-"$v"
  rm -rf lib/modules/"$v"
done
ln -sfn vmlinuz-$new boot/vmlinuz
ln -sfn initrd.img-$new boot/initrd.img
ln -sfn vmlinuz-$run boot/vmlinuz.old
ln -sfn initrd.img-$run boot/initrd.img.old
ls -l boot
