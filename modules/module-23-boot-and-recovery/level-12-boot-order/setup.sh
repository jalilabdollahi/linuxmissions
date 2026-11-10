#!/bin/bash
# Firmware Boots the Network. A level-local efibootmgr mock (python3) keeps NVRAM in
# .efi/nvram. Two "ubuntu" entries: Boot0001 points at the PARTUUID of a replaced disk
# (not in blkid.txt), Boot0003 at the current ESP. Starting order puts PXE first.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p .efi bin .lm-state
OLD=c91d4b0e-2a6f-4e53-8d17-93a5f0b7c2e1
NEW=7f3e2a10-5c4b-4d9e-9a21-6b0c8d1e4f77
USB=0a5c7e91-4d2b-4a68-b3f0-1e9c8d7a6b52
cat > blkid.txt <<EOT
/dev/nvme0n1p1: UUID="3F4A-91C2" BLOCK_SIZE="512" TYPE="vfat" PARTLABEL="EFI System Partition" PARTUUID="$NEW"
/dev/nvme0n1p2: UUID="5b0e2c1a-93d4-4f0e-8a61-0c7d4be21f35" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="2d6c91fa-1b3e-4c77-8e50-a4f2b9d03c18"
/dev/nvme0n1p3: UUID="9e1f0c7a-6a2d-4b8e-b1c4-3f5d7a8e2b60" TYPE="swap" PARTUUID="e84b3a15-7c9d-4f20-a6b1-5d0e3c8f9a27"
/dev/sda1: LABEL="RESCUE" UUID="B1C2-D3E4" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="$USB"
EOT
cat > .efi/nvram <<EOT
BootCurrent: 0000
Timeout: 2
BootOrder: 0000,0004,0001,0002,0003
entry|0000|*|UEFI: PXE IPv4 Intel(R) I210 Gigabit Network Connection|PciRoot(0x0)/Pci(0x1c,0x4)/Pci(0x0,0x0)/MAC(3cecef112233,1)/IPv4(0.0.0.00.0.0.0)
entry|0001|*|ubuntu|HD(1,GPT,$OLD,0x800,0x100000)/File(\\EFI\\ubuntu\\shimx64.efi)
entry|0002|*|UEFI: USB Rescue Stick|HD(1,GPT,$USB,0x800,0x32000)/File(\\EFI\\BOOT\\BOOTX64.EFI)
entry|0003|*|ubuntu|HD(1,GPT,$NEW,0x800,0x100000)/File(\\EFI\\ubuntu\\shimx64.efi)
entry|0004|*|UEFI: PXE IPv6 Intel(R) I210 Gigabit Network Connection|PciRoot(0x0)/Pci(0x1c,0x4)/Pci(0x0,0x0)/MAC(3cecef112233,1)/IPv6(0000:0000:0000:0000:0000:0000:0000:0000)
EOT

cat > bin/efibootmgr <<'PYEOF'
#!/usr/bin/env python3
"""efibootmgr (mock): shows and edits a captured copy of the UEFI boot entries.

usage: efibootmgr [-v] [-o XXXX,YYYY,...] [-n XXXX | -N] [-t SECS | -T] [-b XXXX -a | -A]
  (no option)  list BootCurrent, Timeout, BootOrder and the entries
  -v           also print each entry's device path
  -o ORDER     set BootOrder (comma separated hex entry numbers, first boots first)
  -n XXXX      set BootNext (one-off next boot);  -N  delete BootNext
  -t SECS      set Timeout;  -T  delete Timeout
  -b XXXX -a   mark an entry active;  -b XXXX -A  mark it inactive
The state lives in .efi/nvram next to this script's sandbox (this mock never touches
real firmware). Output format and exit status follow the real tool: 0 on success, 1 on error.
"""
import os, sys

STATE = os.path.join(os.environ.get("SANDBOX", os.getcwd()), ".efi", "nvram")

def load():
    d = {"BootCurrent": "", "Timeout": None, "BootOrder": [], "BootNext": None, "entries": []}
    for line in open(STATE).read().splitlines():
        if line.startswith("entry|"):
            _, num, flag, label, path = line.split("|", 4)
            d["entries"].append([num, flag, label, path])
        elif ":" in line:
            k, v = line.split(":", 1)
            v = v.strip()
            if k == "BootOrder": d[k] = [x for x in v.split(",") if x]
            elif k == "Timeout": d[k] = v or None
            elif k == "BootNext": d[k] = v or None
            else: d[k] = v
    return d

def save(d):
    out = ["BootCurrent: %s" % d["BootCurrent"]]
    if d["Timeout"] is not None: out.append("Timeout: %s" % d["Timeout"])
    if d["BootNext"] is not None: out.append("BootNext: %s" % d["BootNext"])
    out.append("BootOrder: %s" % ",".join(d["BootOrder"]))
    for e in d["entries"]: out.append("entry|%s|%s|%s|%s" % tuple(e))
    open(STATE, "w").write("\n".join(out) + "\n")

def show(d, verbose):
    print("BootCurrent: %s" % d["BootCurrent"])
    if d["Timeout"] is not None: print("Timeout: %s seconds" % d["Timeout"])
    if d["BootNext"] is not None: print("BootNext: %s" % d["BootNext"])
    print("BootOrder: %s" % ",".join(d["BootOrder"]))
    for num, flag, label, path in d["entries"]:
        flag = "*" if flag == "*" else " "
        print("Boot%s%s %s%s" % (num, flag, label, "\t" + path if verbose else ""))

def die(msg):
    print("efibootmgr: " + msg, file=sys.stderr); sys.exit(1)

def main(argv):
    if not os.path.exists(STATE): die("EFI variables are not supported on this system.")
    d = load(); verbose = False; changed = False; b = None; act = None
    nums = {e[0] for e in d["entries"]}
    def hexnum(s):
        s = s.upper().replace("BOOT", "")
        if len(s) != 4 or any(c not in "0123456789ABCDEF" for c in s): die("'%s' is not a valid boot entry number" % s)
        return s
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("-h", "--help"): print(__doc__); return
        elif a in ("-v", "--verbose"): verbose = True
        elif a in ("-o", "--bootorder"):
            i += 1
            if i >= len(argv): die("option requires an argument -- 'o'")
            order = [hexnum(x) for x in argv[i].split(",") if x]
            for n in order:
                if n not in nums: die("entry Boot%s does not exist" % n)
            if len(set(order)) != len(order): die("BootOrder contains a duplicate entry")
            d["BootOrder"] = order; changed = True
        elif a in ("-n", "--bootnext"):
            i += 1; n = hexnum(argv[i])
            if n not in nums: die("entry Boot%s does not exist" % n)
            d["BootNext"] = n; changed = True
        elif a in ("-N", "--delete-bootnext"): d["BootNext"] = None; changed = True
        elif a in ("-t", "--timeout"): i += 1; d["Timeout"] = argv[i]; changed = True
        elif a in ("-T", "--delete-timeout"): d["Timeout"] = None; changed = True
        elif a in ("-b", "--bootnum"): i += 1; b = hexnum(argv[i])
        elif a in ("-a", "--active"): act = "*"
        elif a in ("-A", "--inactive"): act = " "
        else: die("unrecognized option '%s'" % a)
        i += 1
    if act is not None:
        if b is None or b not in nums: die("-a/-A need -b with an existing entry")
        for e in d["entries"]:
            if e[0] == b: e[1] = act
        changed = True
    if changed: save(d)
    show(d, verbose)

main(sys.argv[1:])
PYEOF
chmod +x bin/efibootmgr
ln -sf bin/efibootmgr efibootmgr
cksum bin/efibootmgr blkid.txt > .lm-state/sums
grep '^entry|' .efi/nvram > .lm-state/entries
grep '^BootOrder' .efi/nvram > .lm-state/order0
