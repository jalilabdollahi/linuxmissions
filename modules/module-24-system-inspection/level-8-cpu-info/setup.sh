#!/bin/bash
# capture/<host>.cpuinfo for three hosts, random per setup:
#   - a 2-socket server with hyperthreading and non-contiguous core ids that
#     repeat on both sockets;
#   - a 1-socket server (HT on or off);
#   - a VM whose hypervisor reports every vCPU as its own socket
#     (physical id 0..n-1, core id 0 everywhere).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# Licence audit: database servers

The vendor wants sockets, physical cores and threads for each server.
capture/<host>.cpuinfo are the saved /proc/cpuinfo files. Report what each
file says about its machine, in licence.csv:

  host,sockets,cores,threads

(host = the file name without .cpuinfo)
T
python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
names = sorted(R.sample(["db-alpha", "db-bravo", "db-delta", "db-echo", "db-gamma", "db-sigma"], 3))
models = [("GenuineIntel", "Intel(R) Xeon(R) Gold 6230 CPU @ 2.10GHz", 6, 85, 7),
          ("GenuineIntel", "Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz", 6, 85, 7),
          ("AuthenticAMD", "AMD EPYC 7302 16-Core Processor", 23, 49, 0),
          ("GenuineIntel", "Intel(R) Xeon(R) CPU E5-2650 v4 @ 2.20GHz", 6, 79, 1)]
def core_ids(n):                       # non-contiguous, like real silicon
    ids = sorted(R.sample(range(0, 2 * n + 4), n))
    return ids
def block(cpu, v, sock, core, siblings, cores, mhz, apic):
    vendor, name, fam, mod, step = v
    return ("processor\t: %d\nvendor_id\t: %s\ncpu family\t: %d\nmodel\t\t: %d\nmodel name\t: %s\nstepping\t: %d\n"
            "cpu MHz\t\t: %s\ncache size\t: 28160 KB\nphysical id\t: %d\nsiblings\t: %d\ncore id\t\t: %d\ncpu cores\t: %d\n"
            "apicid\t\t: %d\nfpu\t\t: yes\ncpu_family_flags\t: yes\nflags\t\t: fpu vme de pse tsc msr pae mce cx8 apic sep ht syscall nx lm constant_tsc avx2\n"
            "bogomips\t: 4200.00\nclflush size\t: 64\naddress sizes\t: 46 bits physical, 48 bits virtual\n\n"
            % (cpu, vendor, fam, mod, name, step, mhz, sock, siblings, core, cores, apic)).replace("cpu_family_flags\t: yes\n", "")
res = {}
def phys(name, v, sockets, cores_per, ht):
    ids = core_ids(cores_per)
    out = []; cpu = 0
    for t in range(ht):
        for s in range(sockets):
            for c in ids:
                out.append(block(cpu, v, s, c, cores_per * ht, cores_per, "2100.000", s * 64 + c * 2 + t)); cpu += 1
    open("capture/%s.cpuinfo" % name, "w").write("".join(out))
    res[name] = (sockets, sockets * cores_per, sockets * cores_per * ht)
kinds = ["two", "one", "vm"]
R.shuffle(kinds)
for name, kind in zip(names, kinds):
    v = R.choice(models)
    if kind == "two":
        phys(name, v, 2, R.choice([6, 8, 10, 12, 14]), 2)
    elif kind == "one":
        phys(name, v, 1, R.choice([6, 8, 12, 16]), R.choice([1, 2]))
    else:
        n = R.choice([4, 6, 8])
        out = []
        for i in range(n):
            out.append(block(i, v, i, 0, 1, 1, "2394.374", i))
        open("capture/%s.cpuinfo" % name, "w").write("".join(out))
        res[name] = (n, n, n)
with open(".lm-state/expected", "w") as f:
    f.write("host,sockets,cores,threads\n")
    for n in names:
        f.write("%s,%d,%d,%d\n" % ((n,) + res[n]))
PY
