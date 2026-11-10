#!/bin/bash
# Builds a captured sysfs USB tree (capture/sys/...): real device directories under
# sys/devices/.../usbN/, and sys/bus/usb/devices/ holding symlinks to them, as on a
# real host. Device and interface directories carry the real attribute files
# (idVendor, idProduct, product, bDeviceClass, bInterfaceClass). A random set of
# mass-storage devices is allowlisted; the rest are rogue. The storage class sits on
# the interface, composite devices and a commented-out allowlist line are mixed in.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# Removable media audit, workstation ws-114

Policy: only USB mass-storage devices listed in usb-allowlist.txt may be
plugged in. Security saved the USB part of /sys from ws-114 as capture/sys/.
Which storage devices are NOT on the allowlist?
T
python3 - "$RANDOM$$" <<'PY'
import os, random, sys
R = random.Random(int(sys.argv[1]))
base = "capture/sys/devices/pci0000:00/0000:00:14.0"
bus = "capture/sys/bus/usb/devices"
os.makedirs(bus)

def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text + "\n")

def device(root, name, cls, vid, pid, product, manu, ifaces):
    """ifaces: list of (number, class)"""
    d = "%s/%s" % (root, name)
    w(d + "/idVendor", vid); w(d + "/idProduct", pid)
    w(d + "/product", product); w(d + "/manufacturer", manu)
    w(d + "/bDeviceClass", cls)
    w(d + "/busnum", name.split("-")[0].replace("usb", "")); w(d + "/speed", "480")
    for n, c in ifaces:
        i = "%s/%s:1.%d" % (d, name, n)
        w(i + "/bInterfaceClass", c)
        w(i + "/bInterfaceNumber", "%02d" % n)
        link = "%s/%s:1.%d" % (bus, name, n)
        os.symlink("../../../" + os.path.relpath(i, "capture/sys"), link)
    os.symlink("../../../" + os.path.relpath(d, "capture/sys"), "%s/%s" % (bus, name))
    return d

# root hubs
for n in (1, 2):
    device(base, "usb%d" % n, "09", "1d6b", "000%d" % (n + 1), "xHCI Host Controller", "Linux xhci-hcd", [(0, "09")])
root1, root2 = base + "/usb1", base + "/usb2"

storage_pool = [
    ("0781", "5581", "Ultra", "SanDisk"), ("0781", "5567", "Cruzer Blade", "SanDisk"),
    ("0951", "1666", "DataTraveler 3.0", "Kingston"), ("058f", "6387", "Flash Drive", "Generic"),
    ("090c", "1000", "Flash Drive", "Silicon Motion"), ("13fe", "4300", "USB DISK 2.0", "Kingston"),
    ("154b", "00ee", "Store n Go", "PNY"), ("0bc2", "2321", "Expansion Desk", "Seagate"),
    ("1058", "25a2", "Elements SE", "Western Digital"), ("abcd", "1234", "UDisk", "Generic"),
    ("04e8", "61f5", "Portable SSD T5", "Samsung"), ("0930", "6545", "TransMemory", "Toshiba"),
]
R.shuffle(storage_pool)
others = [  # (class, vid, pid, product, manufacturer, [iface classes])
    ("00", "046d", "c52b", "USB Receiver", "Logitech", ["03", "03", "03"]),
    ("00", "046d", "0825", "Webcam C270", "Logitech", ["0e", "0e", "01", "01"]),
    ("00", "413c", "2113", "Dell KB216 Keyboard", "Dell", ["03"]),
    ("00", "0bda", "8153", "USB 10/100/1000 LAN", "Realtek", ["ff"]),
    ("00", "04f9", "0042", "HL-L2350DW series", "Brother", ["07"]),
    ("00", "8087", "0a2b", "Bluetooth Radio", "Intel", ["e0", "e0"]),
]
ports = ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-7", "2-1", "2-2", "2-3", "2-4", "2-5", "2-6"]
R.shuffle(ports)
# a hub on 1-1 with children 1-1.1 .. 1-1.4
device(root1, "1-1", "09", "05e3", "0610", "USB2.0 Hub", "GenesysLogic", [(0, "09")])
hub = root1 + "/1-1"
sub = ["1-1.1", "1-1.2", "1-1.3", "1-1.4"]
slots = [(root1, p) for p in ("1-2", "1-3", "1-4", "1-5")] + [(hub, p) for p in sub] + [(root2, p) for p in ("2-1", "2-2", "2-3")]
R.shuffle(slots)
n_stor = R.randint(4, 5)
devs = [("stor", storage_pool[k]) for k in range(n_stor)]
for o in others[:len(slots) - 2 - n_stor]:
    devs.append(("other", o))
# two composite devices: a dual-LUN card reader (two storage interfaces) and a
# keyboard with a built-in card reader (HID interfaces plus one storage interface)
composite = ("00", "058f", "6366", "Multi Flash Reader", "Alcor Micro", ["08", "08"])
kb_reader = ("00", "04d9", "a0f6", "Keyboard with Card Reader", "Holtek", ["03", "03", "08"])
devs.append(("comp", composite)); devs.append(("comp", kb_reader))
R.shuffle(devs)
placed = []
for (root, port), (kind, data) in zip(slots, devs):
    if kind == "stor":
        vid, pid, prod, manu = data
        device(root, port, "00", vid, pid, prod, manu, [(0, "08")])
        placed.append((port, vid, pid, prod, manu))
    else:
        cls, vid, pid, prod, manu, ifs = data
        device(root, port, cls, vid, pid, prod, manu, list(enumerate(ifs)))
        if "08" in ifs:
            placed.append((port, vid, pid, prod, manu))
R.shuffle(placed)
n_allowed = R.randint(2, len(placed) - 2)
allow_lines, expected = [], []
for k, (port, vid, pid, prod, manu) in enumerate(placed):
    if k < n_allowed:
        allow_lines.append("%s:%s  # %s %s" % (vid.upper() if R.random() < 0.5 else vid, pid, manu, prod))
    else:
        expected.append("%s %s:%s %s" % (port, vid, pid, prod))
# allowlist traps: a disabled entry for a device still plugged in is not an allowance
# (the same vendor id with another product id is a different device)
if expected:
    e = R.choice(expected).split()
    vp = e[1]
    allow_lines.insert(R.randint(0, len(allow_lines)), "# %s  revoked 2026-02 (lost drive)" % vp)
    allow_lines.insert(0, "%s:%s  # same vendor, different model" % (vp.split(":")[0], format((int(vp.split(":")[1], 16) + 1) % 65536, "04x")))
allow = ["# USB mass-storage allowlist, ws fleet (vendor:product)", "# one entry per line; text after # is a comment", ""] + allow_lines
open("usb-allowlist.txt", "w").write("\n".join(allow) + "\n")
open(".lm-state/expected", "w").write("\n".join(sorted(expected)) + "\n")
PY
