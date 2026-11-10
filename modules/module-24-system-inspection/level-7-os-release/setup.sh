#!/bin/bash
# fleet/<host>/etc/os-release for 15 hosts, random per setup. Some are
# relative symlinks to ../usr/lib/os-release (as on real systems), values
# are quoted or not. The mix always has 5-7 EOL hosts, a Debian 12 and a
# Rocky 9.3 (not EOL: eol.csv knows them by major version only).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p fleet .lm-state
cat > eol.csv <<'T'
id,major,eol_date
ubuntu,18.04,2023-05-31
ubuntu,20.04,2025-05-29
ubuntu,22.04,2027-06-01
ubuntu,24.04,2029-05-31
debian,10,2024-06-30
debian,11,2026-08-31
debian,12,2028-06-10
debian,13,2030-06-30
centos,7,2024-06-30
centos,8,2021-12-31
rocky,8,2029-05-31
rocky,9,2032-05-31
almalinux,8,2029-03-01
almalinux,9,2032-05-31
T
cat > TICKET.md <<'T'
# Audit: end-of-life operating systems

fleet/ holds a copy of /etc from each of the 15 servers (fleet/<host>/etc/).
eol.csv gives the end-of-life date per distribution ID and MAJOR version.
List the hosts that are at or past end of life on 2026-11-10.
T
python3 - "$RANDOM$$" <<'PY'
import os, random, sys
R = random.Random(int(sys.argv[1]))
eol = [("ubuntu", "18.04"), ("ubuntu", "20.04"), ("debian", "10"), ("debian", "11"), ("centos", "7"), ("centos", "8")]
ok = [("ubuntu", "22.04"), ("ubuntu", "24.04"), ("debian", "13"), ("rocky", "8.9"), ("almalinux", "9.2"), ("almalinux", "8.10")]
n_eol = R.randint(5, 7)
fleet = R.sample(eol, 5) + R.choices(eol, k=n_eol - 5)
fleet += [("debian", "12"), ("rocky", "9.3")] + R.choices(ok, k=15 - len(fleet) - 2)
R.shuffle(fleet)
roles = R.sample(["web", "db", "cache", "mail", "build", "queue", "dns", "ldap", "git", "proxy", "metrics", "vault", "ci", "backup", "files", "log"], 15)
names = {"ubuntu": "Ubuntu", "debian": "Debian GNU/Linux", "centos": "CentOS Linux", "rocky": "Rocky Linux", "almalinux": "AlmaLinux"}
like = {"ubuntu": "debian", "debian": "", "centos": "rhel fedora", "rocky": "rhel centos fedora", "almalinux": "rhel centos fedora"}
want = []
for role, (i, v) in zip(roles, fleet):
    host = "%s-%02d" % (role, R.randint(1, 9))
    major = v.split(".")[0] if i != "ubuntu" else v
    pretty = "%s %s" % (names[i], v)
    q = R.random() < 0.5
    def val(x, always=False):
        return '"%s"' % x if (q or always or " " in x) else x
    lines = ['PRETTY_NAME="%s"' % pretty, 'NAME="%s"' % names[i], "VERSION_ID=" + val(v), 'VERSION="%s"' % v, "ID=" + (i if not q else val(i))]
    if like[i]:
        lines.append("ID_LIKE=" + ('"%s"' % like[i] if " " in like[i] else like[i]))
    lines.append("HOME_URL=\"https://example.org/%s\"" % i)
    os.makedirs("fleet/%s/etc" % host)
    if R.random() < 0.45:
        os.makedirs("fleet/%s/usr/lib" % host)
        open("fleet/%s/usr/lib/os-release" % host, "w").write("\n".join(lines) + "\n")
        os.symlink("../usr/lib/os-release", "fleet/%s/etc/os-release" % host)
    else:
        open("fleet/%s/etc/os-release" % host, "w").write("\n".join(lines) + "\n")
    eolrow = {l.split(",")[0] + "," + l.split(",")[1]: l.split(",")[2] for l in open("eol.csv").read().split("\n")[1:] if l}
    if eolrow[i + "," + major] <= "2026-11-10":
        want.append((host, i, v))
want.sort()
open(".lm-state/expected", "w").write("".join("%s %s %s\n" % w for w in want))
PY
