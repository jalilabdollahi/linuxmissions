#!/bin/bash
# Builds a captured config tree of a node (capture/etc/sysctl.conf, capture/etc/sysctl.d,
# capture/run/sysctl.d, capture/usr/lib/sysctl.d), Ubuntu style: etc/sysctl.d/99-sysctl.conf
# is a symlink to ../sysctl.conf. Values change per setup, the structure is fixed:
# same-named files mask lower directories, "9-" sorts after "60-", a hardening file in
# run/ sorts after sysctl.conf and switches ip_forward off, one key is written with
# slashes. The expected answer comes from a systemd-sysctl style simulation.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture/etc/sysctl.d capture/run/sysctl.d capture/usr/lib/sysctl.d .lm-state
cat > TICKET.md <<'T'
# k8s-node-12 does not forward packets

Pods on k8s-node-12 cannot reach each other, as if net.ipv4.ip_forward were 0,
although /etc/sysctl.conf sets it to 1. The node's configuration was captured
in capture/ (etc, run, usr/lib). Which file really decides each setting?
Write effective.txt: one line `key=value file` per key, sorted by key.
T
python3 - "$RANDOM$$" <<'PY'
import os, random, re, sys
R = random.Random(int(sys.argv[1]))
sw_legacy = R.choice([10, 20, 15]); sw_perf = R.choice([1, 5, 3]); sw_conf = R.choice([30, 40, 25])
rp_cloud = R.choice([1, 2]); soma = R.choice([1024, 2048, 512]); mm = R.choice([262144, 524288, 655360])
files = {
 "usr/lib/sysctl.d/10-network-defaults.conf": """# Shipped by procps: network defaults
net.ipv4.ip_forward = 0
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.tcp_syncookies = 1
""",
 "usr/lib/sysctl.d/50-coredump.conf": """# systemd-coredump
kernel.core_pattern = |/lib/systemd/systemd-coredump %%P %%u %%g %%s %%t 9223372036854775808 %%h
kernel.core_uses_pid = 1
""",
 "usr/lib/sysctl.d/60-vm.conf": """vm.overcommit_memory = 1
""",
 "etc/sysctl.d/10-network-defaults.conf": """# local override of the packaged file: only this is kept
net.ipv4.tcp_syncookies = 1
""",
 "etc/sysctl.d/30-k8s.conf": """# kubernetes node prerequisites
net/ipv4/ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
vm.max_map_count = %d
""" % mm,
 "etc/sysctl.d/60-performance.conf": """; tuning
vm.swappiness = %d
net.core.somaxconn = %d
net.ipv4.ip_local_port_range = 32768    60999
""" % (sw_perf, soma),
 "etc/sysctl.d/9-legacy.conf": """# old tuning from the previous team
vm.swappiness = %d
-kernel.sysrq = 1
""" % sw_legacy,
 "run/sysctl.d/20-cloud-init.conf": """# written at boot by cloud-init
net.ipv4.conf.all.rp_filter = %d
net.ipv4.conf.default.rp_filter = %d
""" % (rp_cloud, rp_cloud),
 "run/sysctl.d/50-coredump.conf": """# runtime override of the packaged file
kernel.core_pattern = core
""",
 "run/sysctl.d/99-zz-hardening.conf": """# CIS hardening, written by the compliance agent
net.ipv4.ip_forward = 0
kernel.kptr_restrict = 2
""",
 "etc/sysctl.conf": """# /etc/sysctl.conf - local settings
net.ipv4.ip_forward=1
kernel.sysrq = 0
vm.swappiness=%d
""" % sw_conf,
}
for p, body in files.items():
    path = "capture/" + p
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(body.replace("%%", "%"))
os.symlink("../sysctl.conf", "capture/etc/sysctl.d/99-sysctl.conf")

# ---- simulation (systemd-sysctl rules): /etc > /run > /usr/lib per file name,
# all files sorted by name, later assignments win
prio = ["etc/sysctl.d", "run/sysctl.d", "usr/lib/sysctl.d"]
byname = {}
masked = []
for d in prio:
    for n in sorted(os.listdir("capture/" + d)):
        if n in byname:
            masked.append(d + "/" + n)
        else:
            byname[n] = d + "/" + n
eff = {}
def read(path):
    out = []
    for line in open("capture/" + path):
        line = line.strip()
        if not line or line[0] in "#;" or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k = k.strip().lstrip("-").replace("/", ".")
        out.append((k, " ".join(v.split())))
    return out
for n in sorted(byname):
    for k, v in read(byname[n]):
        eff[k] = (v, byname[n])
masked_keys = set()
for m in masked:
    for k, v in read(m):
        masked_keys.add(k)
only_masked = sorted(masked_keys - set(eff))
with open(".lm-state/expected", "w") as f:
    for k in sorted(eff):
        f.write("%s=%s %s\n" % (k, eff[k][0], eff[k][1]))
open(".lm-state/only_masked", "w").write("\n".join(only_masked) + "\n")
PY
