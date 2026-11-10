#!/bin/bash
# Package Audit: two dumps of "installed packages" in different formats. prod.txt is
# `dpkg-query -W` output (tab separated, plain names); staging.txt came from
# `-f='${binary:Package} ${Version}\n'` (space separated, multiarch names carry :amd64).
# The expected rows are computed here and kept in .lm/ for validate.sh.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm
python3 - <<'PY'
import random
r = random.Random()
words = ("zlib curl openssl libxml2 libpng sqlite3 bash coreutils tar gzip nginx redis postgresql python3 perl git vim tmux "
         "rsync cron logrotate systemd dbus openssh-server ca-certificates tzdata libc6 libssl3 libffi8 libgcc-s1 libstdc++6 "
         "libcurl4 libidn2-0 libunistring5 libpcre2-8-0 libsystemd0 libudev1 libyaml-0-2 jq gawk sed grep findutils "
         "iproute2 iputils-ping netcat-openbsd chrony fail2ban ufw lvm2 e2fsprogs util-linux mount passwd login "
         "python3-minimal libpython3.12 libreadline8 libncurses6 libtinfo6 libacl1 libattr1 libbz2-1.0 liblzma5 "
         "libzstd1 libseccomp2 libgnutls30 libnettle8 libhogweed6 libgmp10 libp11-kit0").split()
names = sorted(set(words))
r.shuffle(names)
names = names[:r.randint(52, 62)]
def ver():
    return f"{r.randint(1,9)}.{r.randint(0,20)}.{r.randint(0,9)}-{r.randint(1,4)}ubuntu{r.randint(1,3)}.{r.randint(1,6)}"
prod = {n: ver() for n in names}
stag = dict(prod)
only_prod = r.sample(names, r.randint(3, 5))
for n in only_prod: del stag[n]
rest = [n for n in names if n not in only_prod]
changed = r.sample(rest, r.randint(5, 8))
for n in changed:
    stag[n] = ver()
    while stag[n] == prod[n]: stag[n] = ver()
only_stag = []
extra = [w for w in ("auditd", "htop", "strace", "ncdu", "tcpdump", "lsof", "ltrace", "mtr-tiny") if w not in prod]
for n in r.sample(extra, r.randint(2, 3)):
    stag[n] = ver(); only_stag.append(n)
# a package whose versions differ only by trailing revision digit must still count; one that is identical must not
rows = []
for n in sorted(set(prod) | set(stag), key=lambda s: s.encode()):
    p, s = prod.get(n, "-"), stag.get(n, "-")
    if p != s:
        rows.append(f"{n}\t{p}\t{s}")
open(".lm/drift.expected", "w").write("\n".join(rows) + "\n")
ps = list(prod.items()); r.shuffle(ps)
with open("prod.txt", "w") as f:
    for n, v in ps: f.write(f"{n}\t{v}\n")
ss = list(stag.items()); r.shuffle(ss)
multiarch = set(r.sample(sorted(stag), len(stag) * 2 // 5))
with open("staging.txt", "w") as f:
    for n, v in ss: f.write(f"{n}{':amd64' if n in multiarch else ''} {v}\n")
PY
