# Which Initramfs Lacks NVMe?

## Why it works
The initramfs is a (compressed) cpio archive that holds the drivers and scripts needed
to find and mount the root filesystem. If the NVMe driver is not inside, the kernel
cannot see the new system disk and drops to the `(initramfs)` prompt. You looked inside
with the right decompressor and `cpio -t`, then compared the file names exactly:
`nvme-core.ko` is the library, `nvme.ko` is the driver that binds to the disk.

## Common mistakes
- Running `zcat` on a zstd image (Ubuntu's default since 21.04). It fails, prints
  nothing useful, and an empty listing looks like "no nvme here".
- `grep nvme` matching `nvme-core` and `nvme-fabrics` and calling the image good.
- Extracting archives into the sandbox root instead of only listing them.

## Next step
On a real host `lsinitramfs /boot/initrd.img-$(uname -r) | grep nvme` does it in one
step, and `update-initramfs -u -k all` rebuilds the images after you add the driver to
`/etc/initramfs-tools/modules`.
