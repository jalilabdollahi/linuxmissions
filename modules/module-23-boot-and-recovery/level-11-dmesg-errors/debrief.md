# Which Disk Is Failing?

## Why it works
The kernel logs a disk problem where it happens. For a SATA disk that is the ATA layer,
so the first complaints say `ata3.00: exception ... failed command: READ FPDMA QUEUED`
with a media error, long before the block layer reports `I/O error, dev sdb`. The names
are tied together only in the probe lines at boot: `ata3` carries SCSI host 2
(`scsi 2:0:0:0`) and that device is attached as `[sdb]`. Following the chain from port to
SCSI address to letter tells you which physical disk to replace, and the timestamp shows
how long it was struggling (the slow boot) before ext4 gave up and remounted read-only.

## Common mistakes
- `grep sdb dmesg.txt`: the first error it shows is from several seconds after the real start.
- Blaming `ata4`, which only had a slow link reset and recovered (it is an optical drive).
- Mapping `ata3` to `sda` by position; the mapping comes from the log, not from the numbers.

## Next step
`smartctl -a /dev/sdb` (smartmontools) shows reallocated and pending sectors, and
`dmesg -T` prints human timestamps. `ls -l /sys/block/sdb` shows the ata path of a live disk.
