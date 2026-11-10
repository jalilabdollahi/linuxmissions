#!/bin/bash
# The Driver That Never Loads. A level-local modprobe-sim (python3) answers
# "modprobe -n -v MODULE" from sysroot/lib/modules/*/modules.dep and
# sysroot/etc/modprobe.d/*.conf. The real blocker is "install ixgbe /bin/true" in
# 50-nic-workarounds.conf; "blacklist ixgbe" does not stop an explicit load, and
# blacklist-old.conf.disabled is ignored because it does not end in .conf.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
V=6.8.0-45-generic
M=sysroot/etc/modprobe.d
mkdir -p $M sysroot/lib/modules/$V/kernel/drivers/net/ethernet/intel/ixgbe sysroot/lib/modules/$V/kernel/drivers/ptp .lm-state/orig

cat > $M/blacklist.conf <<'EOT'
# This file lists modules which will not be loaded as the result of
# alias expansion, with the purpose of preventing the hotplug subsystem
# to load them. It does not affect autoloading of modules by the kernel.
blacklist nouveau
blacklist ixgbe
blacklist pcspkr
EOT
cat > $M/50-nic-workarounds.conf <<'EOT'
# Rack 4 link flaps: tolerate third-party SFP+ modules (JA, 2023-06)
options ixgbe allow_unsupported_sfp=1
# TODO remove once the new firmware is rolled out
install ixgbe /bin/true
EOT
cat > $M/iwlwifi.conf <<'EOT'
# /etc/modprobe.d/iwlwifi.conf
# iwlwifi will dyamically load either iwldvm or iwlmvm depending on the
# microcode file installed on the system.
softdep iwlwifi post: iwldvm iwlmvm
options iwlwifi power_save=0
EOT
cat > $M/blacklist-old.conf.disabled <<'EOT'
# renamed by Tom in 2021 so it stops applying
install ixgbe /bin/false
EOT

D=sysroot/lib/modules/$V
cat > $D/modules.dep <<'EOT'
kernel/drivers/net/ethernet/intel/ixgbe/ixgbe.ko: kernel/drivers/net/mdio.ko kernel/drivers/ptp/ptp.ko kernel/drivers/pps/pps_core.ko kernel/drivers/dca/dca.ko
kernel/drivers/ptp/ptp.ko: kernel/drivers/pps/pps_core.ko
kernel/drivers/pps/pps_core.ko:
kernel/drivers/dca/dca.ko:
kernel/drivers/net/mdio.ko:
kernel/drivers/net/ethernet/intel/e1000e/e1000e.ko: kernel/drivers/ptp/ptp.ko kernel/drivers/pps/pps_core.ko
EOT
for f in net/ethernet/intel/ixgbe/ixgbe net/mdio ptp/ptp pps/pps_core dca/dca net/ethernet/intel/e1000e/e1000e; do
  mkdir -p "$D/kernel/drivers/$(dirname $f)"; : > "$D/kernel/drivers/$f.ko"
done

cat > modprobe-sim <<'PYEOF'
#!/usr/bin/env python3
"""modprobe-sim: a read-only stand-in for 'modprobe -n -v MODULE' on the server in sysroot/.

usage: modprobe-sim [-n] [-v] [-c] [-d ROOT] MODULE
  -n  dry run (this simulator never loads anything, with or without it)
  -v  print what would be done: 'insmod PATH [options]' or 'install COMMAND'
  -c  dump the configuration it read (like modprobe -c)
  -d  root directory of the server (default: sysroot next to this script)
Reads ROOT/etc/modprobe.d/*.conf (files not ending in .conf are ignored, like modprobe)
and ROOT/lib/modules/<release>/modules.dep. Explicit module names ignore 'blacklist'.
"""
import glob, os, sys

def norm(n):
    return n.replace("-", "_")

def main(argv):
    verbose = dump = False
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sysroot")
    mod = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("-n", "--show-only", "--dry-run"): pass
        elif a in ("-v", "--verbose"): verbose = True
        elif a in ("-c", "--showconfig"): dump = True
        elif a in ("-d", "--dirname"): i += 1; root = argv[i]
        elif a.startswith("-"):
            print("modprobe: invalid option -- '%s'" % a.lstrip("-"), file=sys.stderr); return 1
        else: mod = a
        i += 1
    alias, options, install, black = {}, {}, {}, []
    for path in sorted(glob.glob(os.path.join(root, "etc/modprobe.d/*.conf"))):
        text = open(path).read().replace("\\\n", " ")
        for line in text.splitlines():
            parts = line.split("#", 1)[0].split(None, 2)
            if not parts: continue
            k = parts[0]
            if k == "blacklist" and len(parts) > 1: black.append(norm(parts[1]))
            elif k == "alias" and len(parts) > 2: alias[norm(parts[1])] = norm(parts[2])
            elif k == "options" and len(parts) > 2: options[norm(parts[1])] = (options.get(norm(parts[1])) + " " if norm(parts[1]) in options else "") + parts[2]
            elif k == "install" and len(parts) > 2: install[norm(parts[1])] = parts[2]
    if dump:
        for b in black: print("blacklist " + b)
        for a, m in alias.items(): print("alias %s %s" % (a, m))
        for m, o in options.items(): print("options %s %s" % (m, o))
        for m, c in install.items(): print("install %s %s" % (m, c))
        return 0
    if not mod:
        print("Usage: modprobe-sim [-n] [-v] [-c] MODULE", file=sys.stderr); return 1
    rel = sorted(os.listdir(os.path.join(root, "lib/modules")))[-1]
    dep = {}
    for line in open(os.path.join(root, "lib/modules", rel, "modules.dep")):
        if ":" not in line: continue
        p, d = line.rstrip("\n").split(":", 1)
        dep[norm(os.path.basename(p)[:-3])] = (p, d.split())
    name = alias.get(norm(mod), norm(mod))
    if name not in dep:
        print("modprobe: FATAL: Module %s not found in directory /lib/modules/%s" % (mod, rel), file=sys.stderr)
        return 1
    chain = [dep[norm(os.path.basename(d)[:-3])][0] for d in reversed(dep[name][1])] + [dep[name][0]]
    for p in chain:
        m = norm(os.path.basename(p)[:-3])
        if m in install:
            if verbose: print("install " + install[m])
            continue
        if verbose:
            o = options.get(m)
            print("insmod /lib/modules/%s/%s%s" % (rel, p, " " + o if o else ""))
    return 0

sys.exit(main(sys.argv[1:]))
PYEOF
chmod +x modprobe-sim
mkdir -p bin; cp modprobe-sim bin/modprobe-sim

cp $M/* .lm-state/orig/ 2>/dev/null
cp $M/blacklist-old.conf.disabled .lm-state/orig/
cksum modprobe-sim bin/modprobe-sim sysroot/lib/modules/$V/modules.dep > .lm-state/sums
