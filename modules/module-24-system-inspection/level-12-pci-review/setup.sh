#!/bin/bash
# capture/lspci.txt: `lspci -nnk` of a server (lspci itself is not installed
# in the sandbox image). Devices vary per setup: 2-4 unbound NICs/storage
# controllers (some with a "Kernel modules:" line only, one with nothing),
# plus unbound devices that are out of scope (bridges, USB, VGA), and
# bound devices of the in-scope classes (one bound to vfio-pci).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# storage-07: the 25 GbE card is dead after the swap

capture/lspci.txt is `lspci -nnk` from the box. List the network and storage
devices that have no driver bound, with the module that would normally
drive them: unbound.txt, one `slot [vendor:device] module` line each.
T
python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
# (class text, class code, vendor name+device text, vendor:device, module)
nics = [("Ethernet controller", "0200", "Intel Corporation Ethernet Controller XXV710 for 25GbE SFP28", "8086:158b", "i40e"),
        ("Ethernet controller", "0200", "Intel Corporation 82599ES 10-Gigabit SFI/SFP+ Network Connection", "8086:10fb", "ixgbe"),
        ("Ethernet controller", "0200", "Mellanox Technologies MT27800 Family [ConnectX-5]", "15b3:1017", "mlx5_core"),
        ("Ethernet controller", "0200", "Broadcom Inc. and subsidiaries NetXtreme BCM5720 Gigabit Ethernet PCIe", "14e4:165f", "tg3"),
        ("Network controller", "0280", "Intel Corporation Wi-Fi 6 AX200", "8086:2723", "iwlwifi")]
stor = [("Non-Volatile memory controller", "0108", "Samsung Electronics Co Ltd NVMe SSD Controller PM9A1/PM9A3/980PRO", "144d:a80a", "nvme"),
        ("RAID bus controller", "0104", "Broadcom / LSI MegaRAID SAS-3 3108 [Invader]", "1000:005d", "megaraid_sas"),
        ("Serial Attached SCSI controller", "0107", "Broadcom / LSI SAS3008 PCI-Express Fusion-MPT SAS-3", "1000:0097", "mpt3sas"),
        ("SATA controller", "0106", "Intel Corporation C620 Series Chipset Family SATA Controller [AHCI mode]", "8086:a182", "ahci")]
R.shuffle(nics); R.shuffle(stor)
unb = nics[:2] + stor[:1]                       # unbound, in scope
if R.random() < 0.5: unb.append(nics[2])
bound_in = [stor[1]] + [nics[3] if len(unb) == 3 else nics[4]]
if stor[2:]: bound_in.append(stor[2])
# a device with no module at all (unknown to the kernel)
nomod = ("Ethernet controller", "0200", "Intel Corporation Ethernet Connection E823-C for 25GbE SFP", "8086:188a", None)
unb.append(nomod)
dev = []  # (class text, code, name, id, driver, modules)
bridges = [("Host bridge", "0600", "Intel Corporation Sky Lake-E DMI3 Registers", "8086:2020", None, None),
           ("PCI bridge", "0604", "Intel Corporation Sky Lake-E PCI Express Root Port 1A", "8086:2030", "pcieport", None),
           ("ISA bridge", "0601", "Intel Corporation C620 Series Chipset Family LPC Controller", "8086:a1c2", None, None),
           ("USB controller", "0c03", "Intel Corporation C620 Series Chipset Family USB 3.0 xHCI Controller", "8086:a1af", None, "xhci_pci"),
           ("VGA compatible controller", "0300", "ASPEED Technology, Inc. ASPEED Graphics Family", "1a03:2000", None, "ast"),
           ("SMBus", "0c05", "Intel Corporation C620 Series Chipset Family SMBus", "8086:a1a3", None, "i2c_i801")]
items = []
for c in bridges:
    items.append(c)
for c in unb:
    items.append((c[0], c[1], c[2], c[3], None, c[4]))
for c in bound_in:
    items.append((c[0], c[1], c[2], c[3], c[4], c[4]))
# one NIC bound to vfio-pci (bound, so not listed)
v = ("Ethernet controller", "0200", "Intel Corporation Ethernet Controller X710 for 10GbE SFP+", "8086:1572", "vfio-pci", "i40e")
items.append(v)
R.shuffle(items)
slots = sorted(R.sample([(b, d) for b in (0, 3, 17, 58, 59, 94, 175) for d in range(0, 6)], len(items)))
out = []; want = []
for (cls, code, name, vid, drv, mod), (bus, d) in zip(items, slots):
    slot = "%02x:%02x.0" % (bus, d)
    rev = R.choice(["", " (rev 02)", " (rev 04)", " (rev 01)"])
    out.append("%s %s [%s]: %s [%s]%s" % (slot, cls, code, name, vid, rev))
    out.append("\tSubsystem: %s [%s:%04x]" % (name.split()[0] + " Corporation", vid.split(":")[0], R.randint(0x1000, 0x9999)))
    if drv: out.append("\tKernel driver in use: %s" % drv)
    if mod: out.append("\tKernel modules: %s" % mod)
    out.append("")
    if code[:2] in ("01", "02") and not drv:
        want.append("%s [%s] %s" % (slot, vid, mod or "-"))
open("capture/lspci.txt", "w").write("\n".join(out) + "\n")
open(".lm-state/expected", "w").write("".join(w + "\n" for w in want))
PY
