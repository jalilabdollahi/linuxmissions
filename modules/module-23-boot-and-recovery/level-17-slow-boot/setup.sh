#!/bin/bash
# Why Does Boot Take 2.5 Minutes? Captured `systemd-analyze blame` and `critical-chain`.
# Random variant: systemd-networkd-wait-online (TimeoutStartSec=2min) or
# NetworkManager-wait-online (nm-online --timeout=120) is the unit on the critical chain that
# waits ~2 min. In blame, snapd.seeded and others are slower or similar but not on the chain.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p .lm-state sysroot/usr/lib/systemd/system sysroot/etc/systemd/system
python3 - <<'PYEOF'
import random, hashlib
R = random.SystemRandom()
variant = R.choice("AB")
def fmt(t):
    if t < 1: return "%dms" % round(t * 1000)
    if t < 60:
        s = ("%.3f" % t).rstrip("0").rstrip(".")
        return s + "s"
    m = int(t // 60); s = t - 60 * m
    return "%dmin %ss" % (m, ("%.3f" % s).rstrip("0").rstrip("."))
if variant == "A":
    slow = "systemd-networkd-wait-online.service"; prov = "systemd-networkd.service"
    execs = "/usr/lib/systemd/systemd-networkd-wait-online"
    after = "systemd-networkd.service"; req = "Requires=systemd-networkd.service\n"
    desc = "Wait for Network to be Configured"
else:
    slow = "NetworkManager-wait-online.service"; prov = "NetworkManager.service"
    execs = "/usr/bin/nm-online -s -q --timeout=120"
    after = "NetworkManager.service"; req = "Requires=NetworkManager.service\n"
    desc = "Network Manager Wait Online"
# critical chain, bottom-up: (unit, activation time, duration or None)
t = R.uniform(1.2, 2.5)
chain = []
def add(unit, dur=None, gap=0.0):
    global t
    t += gap
    chain.append((unit, t, dur))
    if dur: t += dur
chain.append(("-.slice", 0.0, None)); chain.append(("system.slice", 0.0, None)); chain.append(("systemd-journald.socket", 0.0, None))
t = R.uniform(1.8, 2.9)
add("systemd-remount-fs.service", R.uniform(0.04, 0.2))
add("cloud-init-local.service", R.uniform(9, 16), R.uniform(0.1, 0.6))
add("network-pre.target", None, R.uniform(0.0, 0.2))
add(prov, R.uniform(0.9, 3.5), R.uniform(0.05, 0.4))
D = 120 + R.uniform(0.02, 0.4)
add(slow, D, R.uniform(0.1, 0.3))
add("network-online.target", None)
add("cloud-init.service", R.uniform(2.1, 6.0)) if R.random() < 0.5 else None
add("ssh.service", R.uniform(0.15, 0.6), R.uniform(0.0, 0.2))
add("multi-user.target", None)
add("graphical.target", None)
# render: chain is bottom-up, print top-down
rows = list(reversed(chain))
lines = ["The time when unit became active or started is printed after the \"@\" character.",
         "The time the unit took to start is printed after the \"+\" character.", ""]
for i, (u, at, d) in enumerate(rows):
    prefix = "" if i == 0 else "  " * (i - 1) + "└─"
    lines.append("%s%s @%s%s" % (prefix, u, fmt(at), (" +" + fmt(d)) if d else ""))
open("critical-chain.txt", "w").write("\n".join(lines) + "\n")
total = chain[-1][1]
kern = R.uniform(2.5, 6.0)
# blame
bl = {}
for u, at, d in chain:
    if d: bl[u] = d
extra = [("snapd.seeded.service", D + R.uniform(8, 40)),
         ("apt-daily-upgrade.service", R.uniform(45, 110)),
         ("apt-daily.service", R.uniform(20, 70)),
         ("man-db.service", R.uniform(14, 40)),
         ("cloud-config.service", R.uniform(8, 20)), ("cloud-final.service", R.uniform(6, 18)),
         ("snapd.service", R.uniform(5, 12)), ("lvm2-monitor.service", R.uniform(2, 6)),
         ("dev-sda2.device", R.uniform(2, 5)), ("systemd-udev-trigger.service", R.uniform(0.8, 2.5)),
         ("systemd-resolved.service", R.uniform(0.3, 1.2)), ("rsyslog.service", R.uniform(0.2, 0.9)),
         ("systemd-logind.service", R.uniform(0.2, 0.8)), ("cron.service", R.uniform(0.01, 0.1)),
         ("systemd-sysctl.service", R.uniform(0.01, 0.1)), ("keyboard-setup.service", R.uniform(0.2, 0.9))]
for u, d in extra: bl.setdefault(u, d)
order = sorted(bl.items(), key=lambda kv: -kv[1])
open("blame.txt", "w").write("".join("%12s %s\n" % (fmt(d), u) for u, d in order))
open("startup.txt", "w").write("Startup finished in %s (kernel) + %s (userspace) = %s\nmulti-user.target reached after %s in userspace.\n" % (fmt(kern), fmt(total), fmt(kern + total), fmt(total)))
open(".lm-state/slow", "w").write(slow + "\n")
open(".lm-state/variant", "w").write(variant + "\n")
unit = """[Unit]
Description=%s
Documentation=man:%s(8)
DefaultDependencies=no
Conflicts=shutdown.target
%sAfter=%s
Before=network-online.target shutdown.target

[Service]
Type=oneshot
ExecStart=%s
RemainAfterExit=yes
TimeoutStartSec=%s

[Install]
WantedBy=network-online.target
""" % (desc, slow[:-8], req, after, execs, "2min" if variant == "A" else "130")
open("sysroot/usr/lib/systemd/system/" + slow, "w").write(unit)
for u, body in (("ssh.service", "[Unit]\nDescription=OpenBSD Secure Shell server\nAfter=network.target auditd.service\n\n[Service]\nExecStart=/usr/sbin/sshd -D $SSHD_OPTS\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target\n"),
                (prov, "[Unit]\nDescription=Network Configuration\n\n[Service]\nType=notify\nExecStart=/usr/lib/systemd/systemd-networkd\n\n[Install]\nWantedBy=multi-user.target\n"),
                ("snapd.seeded.service", "[Unit]\nDescription=Wait until snapd is fully seeded\nAfter=snapd.service\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/snap wait system seed.loaded\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n")):
    p = "sysroot/usr/lib/systemd/system/" + u
    import os
    if not os.path.exists(p): open(p, "w").write(body)
os.makedirs("sysroot/etc/systemd/system/multi-user.target.wants", exist_ok=True)
PYEOF
find sysroot/usr/lib -type f | sort | xargs cksum > .lm-state/usrlib.sums
cksum blame.txt critical-chain.txt > .lm-state/sums
