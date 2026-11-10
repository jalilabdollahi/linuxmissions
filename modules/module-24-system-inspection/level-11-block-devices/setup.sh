#!/bin/bash
# capture/lsblk.json: the JSON of `lsblk -J -o NAME,MODEL,SERIAL,SIZE,TYPE,MOUNTPOINTS`
# for a box with four disks (two of the same model). The failing serial is
# random; which disk it is, the layout and the mounts vary per setup. The
# failing disk always has a partition -> LVM PV -> LV chain with a mount
# three levels down, an unmounted partition (mountpoints [null]), swap, and
# one partition with two mount points.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
python3 - "$RANDOM$$" <<'PY'
import json, random, string, sys
R = random.Random(int(sys.argv[1]))
serials = ["".join(R.choice(string.ascii_uppercase + string.digits) for _ in range(8)) for _ in range(4)]
letters = ["sda", "sdb", "sdc", "sdd"]
R.shuffle(letters)
models = ["ST4000NM0035", "ST4000NM0035", "WDC WD40EFRX", "Samsung SSD 870"]   # two disks of one model
R.shuffle(models)
# which two same-model disks exist: the target is one of the twins half of the time
twins = [i for i, m in enumerate(models) if m == "ST4000NM0035"]
target = R.choice(twins + [R.randrange(4)])
def part(name, size, mounts, children=None, typ="part"):
    d = {"name": name, "model": None, "serial": None, "size": size, "type": typ, "mountpoints": mounts}
    if children: d["children"] = children
    return d
def lv(name, size, mounts):
    return part(name, size, mounts, typ="lvm")
devs = []; expected = None
vg = "vg%d" % R.randint(0, 9)
for i, letter in enumerate(letters):
    if i == target:
        kids = [part(letter + "1", "512M", ["/boot/efi"]),
                part(letter + "2", "1G", ["/boot"]),
                part(letter + "3", "3.6T", [None], [lv(vg + "-root", "100G", ["/"]), lv(vg + "-var", "500G", ["/var"]),
                                                  lv(vg + "-swap", "16G", ["[SWAP]"]), lv(vg + "-data", "2T", ["/srv/data", "/var/lib/mysql"])]),
                part(letter + "4", "10G", [None])]
        expected = ["/dev/" + letter, "/", "/boot", "/boot/efi", "/srv/data", "/var", "/var/lib/mysql"]
    else:
        pool = ["/backup", "/mnt/scratch", "/data%d" % i, "/srv/archive%d" % i, "/opt/store%d" % i]
        R.shuffle(pool)
        kids = [part(letter + "1", "1.8T", [pool[0]]), part(letter + "2", "1.8T", [None])]
        if R.random() < 0.6:
            kids[1]["children"] = [lv("vgx%d-lv" % i, "1.8T", [pool[1]])]
            kids[1]["type"] = "part"
    d = {"name": letter, "model": models[i], "serial": serials[i], "size": "3.6T", "type": "disk", "mountpoints": [None], "children": kids}
    devs.append(d)
devs.sort(key=lambda d: d["name"])
json.dump({"blockdevices": devs}, open("capture/lsblk.json", "w"), indent=3)
open("capture/lsblk.json", "a").write("\n")
ser = serials[target]
open("TICKET.md", "w").write("""# Failing disk

SMART says the drive with serial number %s must be replaced today.
There are two disks of the same model in this server, so go by the serial.

capture/lsblk.json is `lsblk -J` from the server. Write disk.txt: the disk's
device path on the first line, then every path that is still mounted from it
(through partitions and LVM too), one per line, sorted.
""" % ser)
open(".lm-state/expected", "w").write("".join(x + "\n" for x in expected[:1] + sorted(expected[1:])))
PY
