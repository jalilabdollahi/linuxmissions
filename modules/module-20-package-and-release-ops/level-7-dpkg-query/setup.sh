#!/bin/bash
# Autopsy of a Failed Upgrade: a hand-built dpkg status file (no pkgsim needed,
# the real dpkg-query reads it through --admindir). Random mix of states; some
# packages have no Section; broken packages also sit in section libs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p "$SANDBOX/prod/var/lib/dpkg/info" "$SANDBOX/prod/var/lib/dpkg/updates" "$SANDBOX/.lm"
python3 - "$SANDBOX" <<'PY' || exit 1
import random, subprocess, sys
sandbox = sys.argv[1]
r = random.Random()
arch = subprocess.run(["dpkg", "--print-architecture"], capture_output=True, text=True).stdout.strip() or "amd64"
names = set()
def uniq(base):
    n, i = base, 1
    while n in names:
        i += 1
        n = f"{base}{i}"
    names.add(n)
    return n

libs = [uniq(n) for n in r.sample(["libssl3", "libcurl4", "libxml2", "libpng16-16", "libsqlite3-0", "libglib2.0-0",
        "libzstd1", "libicu74", "libpcre2-8-0", "libgnutls30", "libx11-6", "libreadline8", "libffi8", "libbz2-1.0",
        "libyaml-0-2", "libpq5", "libgmp10", "libidn2-0"], 14)]
fully = libs[:12]
broken_libs = libs[12:]
rows = []   # (name, state-line, section, size or None)
for n in fully:
    rows.append((n, "install ok installed", "libs", r.randint(60, 2600)))
for n, st in zip(broken_libs, ["install ok half-configured", "install ok unpacked"]):
    rows.append((n, st, "libs", r.randint(2400, 3800)))
# near-misses for a careless grep: other sections that look like libraries
for n in ["libssl-dev", "libcurl4-openssl-dev", "libxml2-dev", "libglib2.0-dev"]:
    rows.append((uniq(n), "install ok installed", "libdevel", r.randint(900, 5000)))
rows.append((uniq("libgcc-compat"), "install ok installed", "oldlibs", r.randint(100, 900)))
rows.append((uniq("python3-libs-extra"), "install ok installed", "python", r.randint(300, 3000)))
pool = ["bash", "coreutils", "grep", "sed", "tar", "gzip", "nginx", "openssh-server", "cron", "rsyslog", "curl", "wget",
        "git", "vim-tiny", "nano", "tzdata", "ca-certificates", "sudo", "systemd", "dbus", "apt", "dpkg", "perl-base",
        "python3-minimal", "logrotate", "iproute2", "iputils-ping", "ufw", "fail2ban", "postgresql-16", "redis-server",
        "haproxy", "chrony", "lsof", "htop", "jq", "rsync", "unzip", "zip", "less", "man-db", "netcat-openbsd"]
sections = ["admin", "utils", "net", "web", "database", "shells", "text", "python", "perl", "devel", "editors", "mail"]
good = r.sample(pool, 28)
for n in good:
    rows.append((uniq(n), "install ok installed", r.choice(sections), r.randint(10, 20000)))
# held (fine) and a few interesting states
for n in r.sample([g for g in good], 2):
    rows = [(a, "hold ok installed", c, d) if a == n else (a, b, c, d) for a, b, c, d in rows]
stuck = r.sample(["openssh-server", "nginx", "cron", "rsyslog", "postgresql-16", "haproxy", "redis-server", "chrony", "fail2ban", "ufw"], 6)
sel = {}
for n in stuck:
    sel[n] = None
states = ["install ok half-configured", "install ok unpacked", "install ok triggers-pending", "install ok triggers-awaited",
          "install reinstreq half-installed", "install ok half-installed"]
rows = [(a, b, c, d) for a, b, c, d in rows if a not in sel]
for n, st in zip(stuck, states):
    rows.append((n, st, r.choice(sections), r.randint(500, 9000)))
for n in [uniq("oldmon"), uniq("legacy-ntp"), uniq("snapd-glue")]:
    rows.append((n, "deinstall ok config-files", r.choice(sections), r.randint(100, 4000)))
for n in [uniq("telnetd"), uniq("rsh-client")]:
    rows.append((n, "deinstall ok not-installed", r.choice(sections), 0))
for n in [uniq("nis"), uniq("ftpd-old")]:
    rows.append((n, "purge ok not-installed", r.choice(sections), 0))
nosec = r.sample([i for i, x in enumerate(rows) if x[1] == "install ok installed" and x[2] != "libs"], 8)
r.shuffle(rows)
out = []
for i, (n, st, sec, size) in enumerate(rows):
    st_not = "not-installed" in st
    lines = [f"Package: {n}", f"Status: {st}", "Priority: optional"]
    if sec and i not in nosec:
        lines.append(f"Section: {sec}")
    if not st_not:
        lines.append(f"Installed-Size: {size}")
    if st.endswith("triggers-pending"):
        lines.append("Triggers-Pending: /usr/share/man ldconfig")
    if st.endswith("triggers-awaited"):
        lines.append("Triggers-Awaited: man-db")
    lines += ["Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>", f"Architecture: {arch}",
              f"Version: {r.randint(1, 9)}.{r.randint(0, 30)}.{r.randint(0, 9)}-{r.randint(0, 3)}ubuntu{r.randint(1, 9)}",
              f"Description: {n} package", f" Part of the production image."]
    out.append("\n".join(lines) + "\n")
open(sandbox + "/prod/var/lib/dpkg/status", "w").write("\n".join(out))
open(sandbox + "/prod/var/lib/dpkg/available", "w").close()
PY
sha256sum "$SANDBOX/prod/var/lib/dpkg/status" | cut -d' ' -f1 > "$SANDBOX/.lm/status.sha"
