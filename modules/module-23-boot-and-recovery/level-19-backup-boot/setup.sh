#!/bin/bash
# The EFI Partition Is Gone. sysroot/boot/efi/EFI was wiped. backups/ has nightly tarballs of
# /boot (members start with ./boot/...). The newest tarball is truncated; in half of the
# setups the next one is a valid archive with one corrupted EFI file. EFI.SHA256SUMS holds
# the truth. sysroot/boot has newer kernels and grub.cfg than the tarballs, so extracting a
# whole tarball over sysroot/ is also wrong.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p .lm-state backups sysroot/boot/efi
python3 - <<'PYEOF'
import hashlib, json, os, random, shutil, subprocess, tempfile, time
R = random.SystemRandom()
def blob(n): return os.urandom(n)
efi = {  # path under EFI -> (mode, size)
    "ubuntu/shimx64.efi": (0o755, R.randrange(20000, 60000)),
    "ubuntu/grubx64.efi": (0o755, R.randrange(30000, 90000)),
    "ubuntu/mmx64.efi": (0o755, R.randrange(10000, 30000)),
    "ubuntu/grub.cfg": (0o600, 0),
    "ubuntu/BOOTX64.CSV": (0o644, 0),
    "BOOT/BOOTX64.EFI": (0o755, R.randrange(20000, 60000)),
    "BOOT/fbx64.efi": (0o755, R.randrange(10000, 30000)),
}
uuid = "%08x-%04x-%04x-%04x-%012x" % (R.getrandbits(32), R.getrandbits(16), R.getrandbits(16), R.getrandbits(16), R.getrandbits(48))
content = {}
for p, (m, n) in efi.items():
    if p == "ubuntu/grub.cfg": content[p] = ("search.fs_uuid %s root\nset prefix=($root)'/boot/grub'\nconfigfile $prefix/grub.cfg\n" % uuid).encode()
    elif p.endswith(".CSV"): content[p] = "shimx64.efi,ubuntu,,This is the boot entry for Ubuntu\n".encode("utf-16")
    else: content[p] = blob(n)
def make_boot(root, kernels, efi_content, grubcfg):
    b = os.path.join(root, "boot")
    for k in kernels:
        os.makedirs(b, exist_ok=True)
        for pre in ("vmlinuz-", "initrd.img-", "config-"):
            open(os.path.join(b, pre + k), "wb").write(blob(R.randrange(500, 3000)))
    os.makedirs(os.path.join(b, "grub"), exist_ok=True)
    open(os.path.join(b, "grub", "grub.cfg"), "w").write(grubcfg)
    if efi_content is not None:
        for p, data in efi_content.items():
            fp = os.path.join(b, "efi", "EFI", p); os.makedirs(os.path.dirname(fp), exist_ok=True)
            open(fp, "wb").write(data); os.chmod(fp, efi[p][0])
        for dp, dn, fn in os.walk(os.path.join(b, "efi")):
            os.chmod(dp, 0o755)
vers = ["6.8.0-31-generic", "6.8.0-45-generic", "6.8.0-52-generic", "6.11.0-17-generic", "5.15.0-118-generic"]
today = time.time()
N = 6
days = [time.strftime("%Y-%m-%d", time.localtime(today - 86400 * (i + 1))) for i in range(N)]
bad2 = R.random() < 0.5
for i, day in enumerate(days):
    tmp = tempfile.mkdtemp()
    ec = dict(content)
    if i == 1 and bad2:
        ec["ubuntu/grubx64.efi"] = blob(len(content["ubuntu/grubx64.efi"]))
    make_boot(tmp, vers[: 2 + i % 3], ec, "# grub.cfg of night %s\nset default=0\n" % day)
    out = "backups/boot-%s.tar.gz" % day
    subprocess.run(["tar", "-czf", out, "-C", tmp, "./boot"], check=True)
    if i == 0:
        size = os.path.getsize(out); cut = int(size * R.uniform(0.45, 0.7))
        data = open(out, "rb").read()[:cut]; open(out, "wb").write(data)
    shutil.rmtree(tmp)
    t = time.mktime(time.strptime(day, "%Y-%m-%d")) + 3 * 3600
    os.utime(out, (t, t))
# the live /boot (newer than every tarball), EFI wiped
make_boot("sysroot", ["6.8.0-52-generic", "6.11.0-19-generic"], None, "# live grub.cfg, newer than any backup\nset default=0\nset timeout=%d\n" % R.randrange(1, 9))
os.makedirs("sysroot/boot/efi", exist_ok=True)
# the truth
sums = []
exp = {}
for p in sorted(content):
    h = hashlib.sha256(content[p]).hexdigest()
    sums.append("%s  EFI/%s\n" % (h, p)); exp["EFI/" + p] = [efi[p][0], h]
open("EFI.SHA256SUMS", "w").write("".join(sums))
dirs = sorted({os.path.dirname("EFI/" + p) for p in content} | {"EFI"})
json.dump({"files": exp, "dirs": dirs}, open(".lm-state/expected.json", "w"))
PYEOF
ls backups | grep -q tar.gz || { echo "setup failed" >&2; exit 1; }
find sysroot -path sysroot/boot/efi -prune -o -type f -print | sort | xargs cksum > .lm-state/outside
cksum EFI.SHA256SUMS > .lm-state/sums
