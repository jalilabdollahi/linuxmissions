#!/bin/bash
# report-renderer keeps dying on render-02. A colleague with root captured the
# kernel ring buffer (`sudo dmesg > dmesg.txt`, raw [seconds-since-boot]
# stamps) and /proc/stat (btime = boot time, epoch). The player lists every
# segfault as "time_utc binary library". Two different binaries crash, in
# different libraries; stamps have 4, 5 and 6 digits before the dot, so the
# bracket is "[ 1234.5]" or "[123456.7]" and naive field splitting breaks.
# AppArmor lines mention report-renderer without being crashes. Boot time,
# crash times, PIDs and libraries are random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p captures .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
rnd = random.Random(sys.argv[1])

CAPTURE = 1794280200 + rnd.randint(-300, 300)               # about 2026-11-10 03:10 UTC
BT = CAPTURE - rnd.randint(110000, 200000)                  # booted 1.3 to 2.3 days earlier
NOW_UP = CAPTURE - BT
lines = []
def k(up, msg):
    lines.append((up, msg))

boot = [
    "Linux version 6.8.0-48-generic (buildd@lcy02-amd64-040) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.2.0-23ubuntu4) 13.2.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #48-Ubuntu SMP PREEMPT_DYNAMIC Fri Sep 27 14:04:52 UTC 2024 (Ubuntu 6.8.0-48.48-generic 6.8.12)",
    "Command line: BOOT_IMAGE=/vmlinuz-6.8.0-48-generic root=UUID=5e2f8a0c-3b7d-4c1e-9a62-0d4f7b1c9e33 ro console=tty1 console=ttyS0",
    "KERNEL supported cpus:",
    "  Intel GenuineIntel",
    "  AMD AuthenticAMD",
    "BIOS-provided physical RAM map:",
    "BIOS-e820: [mem 0x0000000000000000-0x000000000009fbff] usable",
    "BIOS-e820: [mem 0x0000000000100000-0x00000000bffd9fff] usable",
    "NX (Execute Disable) protection: active",
    "DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014",
    "tsc: Detected 2593.906 MHz processor",
    "Memory: 16290712K/16776676K available (22528K kernel code, 4433K rwdata, 14340K rodata, 4980K init, 4720K bss, 485708K reserved, 0K cma-reserved)",
    "smpboot: Allowing 8 CPUs, 0 hotplug CPUs",
    "Freeing SMP alternatives memory: 44K",
    "smpboot: CPU0: Intel Xeon Processor (Icelake) (family: 0x6, model: 0x6a, stepping: 0x6)",
    "smp: Brought up 1 node, 8 CPUs",
    "clocksource: Switched to clocksource kvm-clock",
    "virtio_blk virtio1: [vda] 209715200 512-byte logical blocks (107 GB/100 GiB)",
    " vda: vda1 vda14 vda15",
    "EXT4-fs (vda1): mounted filesystem 5e2f8a0c-3b7d-4c1e-9a62-0d4f7b1c9e33 ro with ordered data mode. Quota mode: none.",
    "systemd[1]: systemd 255.4-1ubuntu8.4 running in system mode (+PAM +AUDIT +SELINUX +APPARMOR +IMA +SMACK +SECCOMP +GCRYPT -GNUTLS +OPENSSL +ACL +BLKID +CURL +ELFUTILS +FIDO2 +IDN2 -IDN +IPTC +KMOD +LIBCRYPTSETUP +LIBFDISK +PCRE2 -PWQUALITY +P11KIT +QRENCODE +TPM2 +BZIP2 +LZ4 +XZ +ZLIB +ZSTD -BPF_FRAMEWORK -XKBCOMMON +UTMP +SYSVINIT default-hierarchy=unified)",
    "systemd[1]: Detected virtualization kvm.",
    "systemd[1]: Hostname set to <render-02>.",
    "EXT4-fs (vda1): re-mounted 5e2f8a0c-3b7d-4c1e-9a62-0d4f7b1c9e33 r/w. Quota mode: none.",
    "audit: type=1400 audit(%d.112:2): apparmor=\"STATUS\" operation=\"profile_load\" profile=\"unconfined\" name=\"report-renderer\" pid=611 comm=\"apparmor_parser\"",
    "virtio_net virtio0 ens3: renamed from eth0",
    "loop0: detected capacity change from 0 to 77656",
]
up = 0.0
for i, m in enumerate(boot):
    if "%d" in m:
        m = m % (BT + int(up))
    k(up, m)
    up += 0.0 if i < 14 else rnd.uniform(0.05, 1.4)

# Background noise over the uptime.
t = 60.0
while t < NOW_UP:
    r = rnd.random()
    if r < 0.55:
        k(t, f"[UFW BLOCK] IN=ens3 OUT= MAC=52:54:00:4a:1b:2c:fe:54:00:3d:9e:01:08:00 SRC={rnd.choice(['45.148.10.', '79.124.62.', '185.242.226.', '162.142.125.'])}{rnd.randint(2, 250)} DST=10.20.0.7 LEN=44 TOS=0x00 PREC=0x00 TTL={rnd.randint(230, 250)} ID={rnd.randint(1000, 65000)} PROTO=TCP SPT={rnd.randint(1024, 65000)} DPT={rnd.choice([22, 23, 3389, 5900, 8080, 9200])} WINDOW=1024 RES=0x00 SYN URGP=0")
    elif r < 0.7:
        pid = rnd.randint(20000, 90000)
        k(t, f"audit: type=1400 audit({BT + int(t)}.{rnd.randint(100, 999)}:{rnd.randint(200, 9000)}): apparmor=\"DENIED\" operation=\"open\" class=\"file\" profile=\"report-renderer\" name=\"/etc/ssl/private/render.key\" pid={pid} comm=\"report-renderer\" requested_mask=\"r\" denied_mask=\"r\" fsuid=998 ouid=0")
    elif r < 0.8:
        k(t, f"perf: interrupt took too long ({rnd.randint(2600, 9000)} > {rnd.randint(2500, 2600)}), lowering kernel.perf_event_max_sample_rate to {rnd.choice([79000, 63000, 50000, 39750])}")
    elif r < 0.9:
        k(t, f"loop{rnd.randint(1, 9)}: detected capacity change from 0 to {rnd.randint(8, 300000)}")
    else:
        k(t, f"workqueue: drm_fb_helper_damage_work hogged CPU for >10000us {rnd.randint(4, 64)} times, consider switching to WQ_UNBOUND")
    t += rnd.uniform(400, 2400)

# The crashes: report-renderer in one or two libraries, pdf-rasterizer in another.
libs = {
    "report-renderer": [("libpng16.so.16.43.0", 0x2f000, 0x14000), ("libcairo.so.2.11800.0", 0x11c000, 0x5a000)],
    "pdf-rasterizer": [("libpoppler.so.134.0.0", 0x2a6000, 0x9d000), ("libfreetype.so.6.20.1", 0xa4000, 0x1c000)],
}
rr = rnd.sample(libs["report-renderer"], rnd.randint(1, 2))
pr = rnd.choice(libs["pdf-rasterizer"])
plan = [("report-renderer", rnd.choice(rr)) for _ in range(rnd.randint(4, 6))] + [("pdf-rasterizer", pr) for _ in range(rnd.randint(2, 3))]
# spread over the uptime: stamps with 4, 5 and 6 digits before the dot
times = sorted([rnd.uniform(1200, 9800), rnd.uniform(10500, 99000)] +
               [rnd.uniform(100500, NOW_UP - 300) for _ in range(len(plan) - 2)])
rnd.shuffle(plan)
for t, (binary, (lib, size, text)) in zip(times, plan):
    pid = rnd.randint(20000, 90000)
    base = 0x7f0000000000 + rnd.randint(0x10000, 0xfffffff) * 0x1000
    ip = base + rnd.randint(0x1000, text)
    cpu = rnd.randint(0, 7)
    k(t, f"{binary}[{pid}]: segfault at {rnd.choice(['0', '8', '10', '18', hex(rnd.randint(0x5600000000, 0x56ffffffff))[2:]])} ip {ip:016x} sp {0x7ffc00000000 + rnd.randint(0, 0x3ffffff) * 16:016x} error {rnd.choice([4, 4, 6])} in {lib}[{base:x}+{size:x}] likely on CPU {cpu} (core {cpu}, socket 0)")
    k(t + 0.000021, "Code: " + " ".join(f"{rnd.randint(0, 255):02x}" for _ in range(21)) + " <48> 8b " + " ".join(f"{rnd.randint(0, 255):02x}" for _ in range(19)))

lines.sort(key=lambda x: x[0])
with open("captures/dmesg.txt", "w") as fh:
    for up, msg in lines:
        fh.write(f"[{up:12.6f}] {msg}\n")

cpu = [rnd.randint(10**6, 10**8) for _ in range(10)]
with open("captures/proc-stat.txt", "w") as fh:
    fh.write("cpu  " + " ".join(str(sum(cpu[i:i + 1]) * 8) for i in range(10)) + "\n")
    for c in range(8):
        fh.write(f"cpu{c} " + " ".join(str(x + rnd.randint(0, 99999)) for x in cpu) + "\n")
    fh.write("intr " + str(rnd.randint(10**8, 10**9)) + " 0 9 0 0 0 0 0 0 0 0 0 0 156 0 0\n")
    fh.write(f"ctxt {rnd.randint(10**8, 10**9)}\n")
    fh.write(f"btime {BT}\n")
    fh.write(f"processes {rnd.randint(200000, 900000)}\n")
    fh.write("procs_running 2\nprocs_blocked 0\n")
    fh.write("softirq " + " ".join(str(rnd.randint(10**5, 10**8)) for _ in range(11)) + "\n")
PY
cat > captures/README <<'EOF'
render-02, captured by mkoster at about 03:10 UTC (we can't read the ring buffer
ourselves: kernel.dmesg_restrict=1 on our servers).

  sudo dmesg > dmesg.txt          # raw kernel ring buffer
  cat /proc/stat > proc-stat.txt  # for the boot time
EOF
cksum captures/dmesg.txt captures/proc-stat.txt > .lm-state/captures.sum
