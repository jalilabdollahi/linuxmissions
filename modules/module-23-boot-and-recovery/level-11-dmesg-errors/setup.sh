#!/bin/bash
# Which Disk Is Failing? A hand-written dmesg excerpt. The failing disk is sdb on
# ata3 (probe lines map ata3 -> scsi 2:0:0:0 -> [sdb]); its first error is an
# "ata3.00: exception" line at 14.201332, long before any line names sdb in an
# error. ata4 (an optical drive) shows a recovered COMRESET: a decoy.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
cat > dmesg.txt <<'EOT'
[    0.000000] Linux version 6.8.0-45-generic (buildd@lcy02-amd64-103) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.2.0-23ubuntu4) 13.2.0) #45-Ubuntu SMP PREEMPT_DYNAMIC Fri Aug 30 12:02:04 UTC 2024
[    0.000000] Command line: BOOT_IMAGE=/vmlinuz-6.8.0-45-generic root=UUID=5b0e2c1a-93d4-4f0e-8a61-0c7d4be21f35 ro quiet splash
[    0.000000] BIOS-provided physical RAM map:
[    0.000000] BIOS-e820: [mem 0x0000000000000000-0x000000000009ffff] usable
[    0.004112] tsc: Detected 3492.000 MHz processor
[    0.081250] smpboot: CPU0: Intel(R) Xeon(R) E-2288G CPU @ 3.70GHz (family: 0x6, model: 0x9e, stepping: 0xd)
[    0.312008] PCI: Using ACPI for IRQ routing
[    0.642551] clocksource: Switched to clocksource tsc
[    1.102345] ahci 0000:00:17.0: AHCI 0001.0301 32 slots 6 ports 6 Gbps 0x3f impl SATA mode
[    1.102351] ahci 0000:00:17.0: flags: 64bit ncq sntf pm led clo only pio slum part ems deso sadm sds apst
[    1.111904] scsi host0: ahci
[    1.112210] scsi host1: ahci
[    1.112498] scsi host2: ahci
[    1.112790] scsi host3: ahci
[    1.113044] ata1: SATA max UDMA/133 abar m2048@0x91a00000 port 0x91a00100 irq 124
[    1.113049] ata2: SATA max UDMA/133 abar m2048@0x91a00000 port 0x91a00180 irq 124
[    1.113053] ata3: SATA max UDMA/133 abar m2048@0x91a00000 port 0x91a00200 irq 124
[    1.113057] ata4: SATA max UDMA/133 abar m2048@0x91a00000 port 0x91a00280 irq 124
[    1.432877] ata1: SATA link up 6.0 Gbps (SStatus 133 SControl 300)
[    1.433710] ata1.00: ATA-11: Samsung SSD 870 EVO 500GB, SVT01B6Q, max UDMA/133
[    1.433716] ata1.00: 976773168 sectors, multi 1: LBA48 NCQ (depth 32), AA
[    1.436002] scsi 0:0:0:0: Direct-Access     ATA      Samsung SSD 870  1B6Q PQ: 0 ANSI: 5
[    1.436611] sd 0:0:0:0: [sda] 976773168 512-byte logical blocks: (500 GB/466 GiB)
[    1.436698] sd 0:0:0:0: [sda] Write Protect is off
[    1.440120] sd 0:0:0:0: [sda] Attached SCSI disk
[    1.752114] ata2: SATA link down (SStatus 0 SControl 300)
[    2.121943] ata3: SATA link up 3.0 Gbps (SStatus 123 SControl 300)
[    2.124871] ata3.00: ATA-10: ST4000DM004-2CV104, 0001, max UDMA/133
[    2.124880] ata3.00: 7814037168 sectors, multi 16: LBA48 NCQ (depth 32), AA
[    2.127331] ata3.00: configured for UDMA/133
[    2.130105] scsi 2:0:0:0: Direct-Access     ATA      ST4000DM004-2CV1 0001 PQ: 0 ANSI: 5
[    2.130672] sd 2:0:0:0: [sdb] 7814037168 512-byte logical blocks: (4.00 TB/3.64 TiB)
[    2.130790] sd 2:0:0:0: [sdb] 4096-byte physical blocks
[    2.133420] sd 2:0:0:0: [sdb] Attached SCSI disk
[    2.480011] ata4: COMRESET failed (errno=-16)
[    2.480022] ata4: reset failed, retrying in 5 secs
[    3.200777] usb 1-1: new high-speed USB device number 2 using xhci_hcd
[    4.115908] EXT4-fs (sda2): mounted filesystem 5b0e2c1a-93d4-4f0e-8a61-0c7d4be21f35 ro with ordered data mode. Quota mode: none.
[    5.219630] ata4: SATA link up 1.5 Gbps (SStatus 113 SControl 300)
[    5.225014] ata4.00: ATAPI: HL-DT-ST DVDRAM GHB0N, NB00, max UDMA/100
[    5.231771] scsi 3:0:0:0: CD-ROM            HL-DT-ST DVDRAM GHB0N     NB00 PQ: 0 ANSI: 5
[    5.249011] sr 3:0:0:0: [sr0] scsi3-mmc drive: 24x/24x writer dvd-ram cd/rw xa/form2 cdda tray
[    6.442680] systemd[1]: systemd 255.4-1ubuntu8.4 running in system mode
[    6.601234] systemd[1]: Detected architecture x86-64.
[    7.020339] systemd[1]: Hostname set to <store-02>.
[    8.331700] EXT4-fs (sda2): re-mounted filesystem 5b0e2c1a-93d4-4f0e-8a61-0c7d4be21f35 r/w.
[    9.004127] systemd-journald[412]: Received client request to flush runtime journal.
[   10.771209] Adding 8388604k swap on /swapfile.  Priority:-2 extents:5 across:8388608k SS
[   11.903355] EXT4-fs (sdb1): mounted filesystem 0e5a6c2d-4b7f-4c1a-9f3e-6d2b8a1c7e40 r/w with ordered data mode. Quota mode: none.
[   12.440120] e1000e 0000:00:1f.6 eno1: NIC Link is Up 1000 Mbps Full Duplex, Flow Control: Rx/Tx
[   14.201332] ata3.00: exception Emask 0x0 SAct 0x1c00 SErr 0x0 action 0x0
[   14.201346] ata3.00: irq_stat 0x40000008
[   14.201350] ata3.00: failed command: READ FPDMA QUEUED
[   14.201358] ata3.00: cmd 60/00:50:00:6a:5d/01:00:1d:00:00/40 tag 10 ncq dma 131072 in
[   14.201358]          res 41/40:00:48:6a:5d/00:00:1d:00:00/00 Emask 0x409 (media error) <F>
[   14.201371] ata3.00: status: { DRDY ERR }
[   14.201375] ata3.00: error: { UNC }
[   14.263841] ata3.00: configured for UDMA/133
[   15.610004] ata3.00: exception Emask 0x0 SAct 0x70 SErr 0x0 action 0x0
[   15.610020] ata3.00: failed command: READ FPDMA QUEUED
[   15.610033] ata3.00: error: { UNC }
[   16.002270] ata3: hard resetting link
[   16.497911] ata3: SATA link up 3.0 Gbps (SStatus 123 SControl 300)
[   21.380518] sd 2:0:0:0: [sdb] tag#10 FAILED Result: hostbyte=DID_OK driverbyte=DRIVER_OK cmd_age=7s
[   21.380527] sd 2:0:0:0: [sdb] tag#10 Sense Key : Medium Error [current]
[   21.380541] sd 2:0:0:0: [sdb] tag#10 Add. Sense: Unrecovered read error - auto reallocate failed
[   21.380549] I/O error, dev sdb, sector 459894344 op 0x0:(READ) flags 0x80700 phys_seg 4 prio class 2
[   30.118820] EXT4-fs error (device sdb1): ext4_find_entry:1608: inode #2: comm rsync: reading directory lblock 0
[   30.118902] EXT4-fs (sdb1): Remounting filesystem read-only
[   33.870004] systemd[1]: srv.mount: Deactivated successfully.
EOT
cksum dmesg.txt > .lm-state/sum
echo "sdb 14.201332" > .lm-state/want
