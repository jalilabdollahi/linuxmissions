#!/bin/bash
# build-07: a server copy (etc/ and home/) plus the shared account mocks and a
# level-local visudo. Traps built in: the highest UID is 1499 so the automatic
# next one (1500) is inside the contractor range the ticket reserves; ben exists,
# locked (!hash), expired, with the nologin shell and a home full of his files;
# etc/default/useradd's shell is /bin/sh; subuid is unsorted with an odd range;
# the sudoers.d file must be named without a dot.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin etc/skel/.config/corp etc/default etc/sudoers.d home/ben home/sven .lm .lm-state
for t in useradd usermod gpasswd chage passwd getent id groups; do cp "$M/accounts/$t" bin/; done
cp "$(dirname "$0")/visudo" bin/visudo
chmod +x bin/visudo
echo 2026-11-10 > .lm/now
echo build-07 > etc/hostname

cat > etc/login.defs <<'LMEND'
MAIL_DIR        /var/mail
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   7
UID_MIN         1000
UID_MAX         60000
SYS_UID_MIN     100
SYS_UID_MAX     999
GID_MIN         1000
GID_MAX         60000
SYS_GID_MIN     100
SYS_GID_MAX     999
USERGROUPS_ENAB yes
HOME_MODE       0750
SUB_UID_MIN     100000
SUB_UID_MAX     600100000
SUB_UID_COUNT   65536
SUB_GID_MIN     100000
SUB_GID_MAX     600100000
SUB_GID_COUNT   65536
LMEND
cat > etc/default/useradd <<'LMEND'
GROUP=100
HOME=/home
INACTIVE=-1
EXPIRE=
SHELL=/bin/sh
SKEL=/etc/skel
CREATE_MAIL_SPOOL=no
LMEND
cat > etc/skel/.bashrc <<'LMEND'
# ~/.bashrc: company default
[[ $- == *i* ]] || return
alias ll='ls -alF'
export EDITOR=vim
LMEND
cat > etc/skel/.profile <<'LMEND'
# ~/.profile: company default
[ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
LMEND
echo '# ~/.bash_logout' > etc/skel/.bash_logout
cat > etc/skel/.config/corp/proxy.conf <<'LMEND'
http_proxy=http://proxy.corp.example:3128
no_proxy=localhost,.corp.example
LMEND

python3 - "$RANDOM$$" <<'PY'
import random, string, sys
R = random.Random(int(sys.argv[1]))
def h():
    c = string.ascii_letters + string.digits + "./"
    return "$y$j9T$" + "".join(R.choice(c) for _ in range(22)) + "$" + "".join(R.choice(c) for _ in range(43))
users = [("kim", 1001, "Kim Nowak", "/bin/bash"), ("tomas", 1002, "Tomas Berg", "/bin/bash"), ("priya", 1005, "Priya Nair", "/bin/bash"),
         ("ben", 1311, "Ben Okafor", "/usr/sbin/nologin"), ("sven", 1499, "Sven Lund", "/bin/bash")]
pw = ["root:x:0:0:root:/root:/bin/bash", "daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin", "sshd:x:105:65534::/run/sshd:/usr/sbin/nologin"]
sh = ["root:*:20400:0:99999:7:::", "daemon:*:20400:0:99999:7:::", "sshd:*:20400:0:99999:7:::"]
gr = ["root:x:0:", "sudo:x:27:", "docker:x:999:kim,sven", "engineers:x:3000:tomas,priya,sven"]
gs = ["root:*::", "sudo:*::", "docker:!::kim,sven", "engineers:!::tomas,priya,sven"]
keep = {}
for u, uid, full, shell in users:
    pw.append("%s:x:%d:%d:%s:/home/%s:%s" % (u, uid, uid, full, u, shell))
    pwh = h()
    if u == "ben":
        keep["BEN_HASH"] = pwh
        sh.append("ben:!%s:19800:1:90:7::20400:" % pwh)
    else:
        sh.append("%s:%s:%d:1:90:7:::" % (u, pwh, R.randint(20000, 20700)))
    gr.append("%s:x:%d:" % (u, uid)); gs.append("%s:!::" % u)
open("etc/passwd", "w").write("\n".join(pw) + "\n")
open("etc/shadow", "w").write("\n".join(sh) + "\n")
open("etc/group", "w").write("\n".join(gr) + "\n")
open("etc/gshadow", "w").write("\n".join(gs) + "\n")
su = ["sven:265536:65536", "kim:100000:65536", "priya:165536:100000", "tomas:331072:65536"]
sg = ["kim:100000:65536", "tomas:165536:65536", "priya:296608:65536", "sven:231072:65536"]
R.shuffle(su); R.shuffle(sg)
open("etc/subuid", "w").write("\n".join(su) + "\n")
open("etc/subgid", "w").write("\n".join(sg) + "\n")
open(".lm-state/hash", "w").write(h())
PY

cat > etc/sudoers <<'LMEND'
Defaults        env_reset
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
root    ALL=(ALL:ALL) ALL
%sudo   ALL=(ALL:ALL) ALL
@includedir /etc/sudoers.d
LMEND
chmod 440 etc/sudoers
printf '# Files here are read by sudo; only names without a dot or ~ are used.\n' > etc/sudoers.d/README
chmod 440 etc/sudoers.d/README

# ben's old home and sven's
printf 'export OLD_TOOLS=1\n' > home/ben/.bashrc
printf 'quarterly numbers\n' > home/ben/notes.txt
mkdir -p home/ben/projects && printf 'draft\n' > home/ben/projects/plan.md
chmod 700 home/ben
chmod 750 home/sven

INITIAL_HASH=$(cat .lm-state/hash)
cat > TICKET.md <<LMEND
# ONB-4417: onboarding on build-07 (start date 2026-11-16)

Engineers, in this order:

  1. Ana Ribeiro      login: ana
  2. Ben Okafor       login: ben     (returning: the account exists, locked and
                                      expired since he left; re-enable it, do not
                                      create a second one, keep his home as it is
                                      and keep his existing password)
  3. Cara Lindholm    login: cara

For all three:
  - comment (full name) as above, login shell /bin/bash
  - supplementary groups: engineers and docker
  - home directory /home/<login> from /etc/skel, mode 0750 (ben's exists: leave it)
  - must change their password at first login: the last-change day is 0
    (ana and cara start with the initial password hash below; ben keeps his)
  - rootless containers: each gets one 65536-ID range in /etc/subuid and in
    /etc/subgid (ben has none yet)

UIDs: 1500-1599 are reserved for the contractor directory and must stay free.
New accounts take the next UIDs from 1600 up, in ticket order. Private groups
use the same number as the UID. Ben keeps his UID.

sudo: members of the group engineers may run any command as any user:
  %engineers ALL=(ALL:ALL) ALL
in /etc/sudoers.d/engineers (mode 0440). It must pass: visudo -c

INITIAL_HASH=$INITIAL_HASH
LMEND

# snapshots for the validator
mkdir -p .lm-state/orig
cp etc/passwd etc/shadow etc/group etc/gshadow etc/subuid etc/subgid etc/sudoers .lm-state/orig/
cksum etc/login.defs etc/default/useradd etc/skel/.bashrc etc/skel/.profile etc/skel/.bash_logout etc/skel/.config/corp/proxy.conf etc/sudoers.d/README > .lm-state/cfg.sum
( cd home/ben && find . -type f -exec cksum {} + | LC_ALL=C sort; ls -ld . | cut -c1-10 ) > .lm-state/ben.home
