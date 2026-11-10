"""Unit tests for the shared account mocks in mocks/accounts/
(useradd, usermod, userdel, groupadd, groupmod, groupdel, gpasswd, passwd,
chage, id, groups, getent).

Run: python3 -m unittest tests.test_mocks_accounts -v   (or scripts/test-levels-docker.sh --unit)
"""
from __future__ import annotations

import os
import shutil
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOCKS = REPO / "mocks" / "accounts"
TOOLS = ("useradd", "usermod", "userdel", "groupadd", "groupmod", "groupdel", "gpasswd", "passwd", "chage",
         "id", "groups", "getent")
TODAY = 20767          # 2026-11-10 in days since the epoch

PASSWD = """\
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
sam:x:1001:1001:Sam Ortiz,,,:/home/sam:/bin/bash
lee:x:1002:1002:Lee Chen,,,:/home/lee:/bin/bash
"""
GROUP = """\
root:x:0:
adm:x:4:syslog,sam
sudo:x:27:sam
www-data:x:33:
users:x:100:
nogroup:x:65534:
systemd-network:x:998:
docker:x:999:lee
sam:x:1001:
lee:x:1002:
dev:x:1050:sam,lee
"""
SHADOW = """\
root:*:19800:0:99999:7:::
daemon:*:19800:0:99999:7:::
sam:$y$j9T$abc$def:20000:0:99999:7:::
lee:!$6$xyz$uvw:20100:0:90:7:::
"""
GSHADOW = """\
root:*::
adm:*::syslog,sam
sudo:*::sam
docker:!::lee
sam:!::
lee:!::
dev:!:sam:sam,lee
"""


class AccountsRoot(unittest.TestCase):
    """A fake root with Ubuntu-format account files and the tools in bin/."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="lm-acct-")
        self.root = Path(self.tmp.name)
        (self.root / "bin").mkdir()
        for t in TOOLS:
            shutil.copy(MOCKS / t, self.root / "bin" / t)     # follows the symlink, like plain `cp`
        (self.root / ".lm").mkdir()
        (self.root / ".lm" / "now").write_text("2026-11-10 09:00\n")
        etc = self.root / "etc"
        (etc / "skel" / ".config").mkdir(parents=True)
        for name, text in (("passwd", PASSWD), ("group", GROUP), ("shadow", SHADOW), ("gshadow", GSHADOW),
                           ("subuid", "lee:165536:65536\nsam:100000:65536\n"),
                           ("subgid", "sam:100000:65536\nlee:165536:65536\n")):
            (etc / name).write_text(text)
        (etc / "skel" / ".bashrc").write_text("# ~/.bashrc\n")
        (etc / "skel" / ".profile").write_text("# ~/.profile\n")
        (etc / "skel" / ".config" / "app.conf").write_text("x=1\n")
        (etc / "skel" / ".bashrc").chmod(0o600)
        (self.root / "home" / "sam").mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def run_tool(self, tool, *args, env=None):
        e = {k: v for k, v in os.environ.items() if not k.startswith("LM_")}
        e.update(env or {})
        return subprocess.run([str(self.root / "bin" / tool), *args], capture_output=True, text=True, env=e,
                              cwd=str(self.root), timeout=30)

    def ok(self, tool, *args):
        r = self.run_tool(tool, *args)
        self.assertEqual(r.returncode, 0, "%s %s: %s" % (tool, args, r.stderr))
        return r

    def fails(self, code, message, tool, *args):
        r = self.run_tool(tool, *args)
        self.assertEqual((r.returncode, r.stderr.strip().splitlines()[0] if r.stderr.strip() else ""),
                         (code, message))
        return r

    def read(self, name):
        return (self.root / "etc" / name).read_text()

    def line(self, name, key):
        for l in self.read(name).splitlines():
            if l.split(":")[0] == key:
                return l
        return None


class UseraddTests(AccountsRoot):
    def test_ubuntu_defaults(self):
        self.ok("useradd", "kim")
        self.assertEqual(self.line("passwd", "kim"), "kim:x:1003:1003::/home/kim:/bin/sh")
        self.assertEqual(self.line("group", "kim"), "kim:x:1003:")
        self.assertEqual(self.line("gshadow", "kim"), "kim:!::")
        self.assertEqual(self.line("shadow", "kim"), "kim:!:%d:0:99999:7:::" % TODAY)
        self.assertFalse((self.root / "home" / "kim").exists())     # no -m, no home
        # lowest free 65536 range above 100000, although the file is unsorted
        self.assertEqual(self.line("subuid", "kim"), "kim:231072:65536")
        self.assertEqual(self.line("subgid", "kim"), "kim:231072:65536")
        # untouched lines stay byte-identical
        self.assertTrue(self.read("passwd").startswith(PASSWD))
        self.assertTrue(self.read("shadow").startswith(SHADOW))

    def test_create_home_from_skel(self):
        self.ok("useradd", "-m", "-s", "/bin/bash", "-c", "Kim Park", "-G", "dev,docker", "kim")
        home = self.root / "home" / "kim"
        self.assertEqual(sorted(p.name for p in home.iterdir()), [".bashrc", ".config", ".profile"])
        self.assertEqual((home / ".config" / "app.conf").read_text(), "x=1\n")
        self.assertEqual(stat.S_IMODE(home.stat().st_mode), 0o750)          # HOME_MODE 0750
        self.assertEqual(stat.S_IMODE((home / ".bashrc").stat().st_mode), 0o600)
        self.assertEqual(self.line("passwd", "kim"), "kim:x:1003:1003:Kim Park:/home/kim:/bin/bash")
        self.assertEqual(self.line("group", "dev"), "dev:x:1050:sam,lee,kim")
        self.assertEqual(self.line("group", "docker"), "docker:x:999:lee,kim")
        self.assertEqual(self.line("gshadow", "dev"), "dev:!:sam:sam,lee,kim")
        r = self.run_tool("useradd", "-m", "sam")
        self.assertEqual(r.returncode, 9)
        r = self.run_tool("useradd", "-m", "-d", "/home/sam", "sam2")
        self.assertEqual(r.returncode, 0)
        self.assertIn("useradd: warning: the home directory /home/sam already exists.", r.stderr)
        self.assertIn("useradd: Not copying any file from skel directory into it.", r.stderr)

    def test_id_allocation(self):
        (self.root / "etc" / "group").write_text(GROUP + "ci:x:1003:\n")
        self.ok("useradd", "lena")
        # UID 1003 is free in passwd but GID 1003 is taken: the group gets the next free GID
        self.assertEqual(self.line("passwd", "lena"), "lena:x:1003:1051::/home/lena:/bin/sh")
        self.ok("useradd", "-r", "metrics")
        # system accounts count down from below the lowest used system ID
        self.assertEqual(self.line("passwd", "metrics"), "metrics:x:997:997::/home/metrics:/bin/sh")
        self.assertEqual(self.line("shadow", "metrics"), "metrics:!:%d::::::" % TODAY)
        self.assertIsNone(self.line("subuid", "metrics"))
        (self.root / "etc" / "login.defs").write_text("UID_MIN 2000\nUID_MAX 60000\nGID_MIN 2000\nGID_MAX 60000\n"
                                                      "PASS_MAX_DAYS 90\nPASS_MIN_DAYS 1\nPASS_WARN_AGE 14\n")
        self.ok("useradd", "-u", "2500", "ops1")
        self.ok("useradd", "ops2")
        self.assertEqual(self.line("passwd", "ops2").split(":")[2], "2501")
        self.assertEqual(self.line("shadow", "ops2"), "ops2:!:%d:1:90:14:::" % TODAY)

    def test_errors(self):
        self.fails(9, "useradd: user 'sam' already exists", "useradd", "sam")
        self.fails(3, "useradd: invalid user name 'Bob': use --badname to ignore", "useradd", "Bob")
        self.fails(6, "useradd: group 'nope' does not exist", "useradd", "-G", "dev,nope", "x1")
        self.fails(6, "useradd: group 'nope' does not exist", "useradd", "-g", "nope", "x1")
        self.fails(4, "useradd: UID 1001 is not unique", "useradd", "-u", "1001", "x1")
        (self.root / "etc" / "group").write_text(GROUP + "x1:x:1500:\n")
        self.fails(9, "useradd: group x1 exists - if you want to add this user to that group, use -g.",
                   "useradd", "x1")
        self.fails(2, "useradd: invalid option -- 'q'", "useradd", "-q", "x1")
        self.fails(2, "mock: option -Z not supported", "useradd", "-Z", "u", "x1")
        self.fails(2, "Usage: useradd [options] LOGIN", "useradd")
        self.fails(3, "useradd: invalid date 'someday'", "useradd", "-e", "someday", "x2")
        self.assertIsNone(self.line("passwd", "x1"))
        self.assertIsNone(self.line("passwd", "x2"))

    def test_primary_group_and_expiry(self):
        self.ok("useradd", "-g", "users", "-e", "2026-12-31", "-f", "7", "temp")
        self.assertEqual(self.line("passwd", "temp"), "temp:x:1003:100::/home/temp:/bin/sh")
        self.assertIsNone(self.line("group", "temp"))
        self.assertEqual(self.line("shadow", "temp"), "temp:!:%d:0:99999:7:7:20818:" % TODAY)
        out = self.ok("useradd", "-D").stdout.splitlines()
        self.assertIn("SHELL=/bin/sh", out)
        self.assertIn("SKEL=/etc/skel", out)


class UsermodTests(AccountsRoot):
    def test_groups_replace_append_remove(self):
        self.ok("usermod", "-G", "docker", "sam")       # without -a: replaces the supplementary groups
        self.assertEqual(self.ok("id", "sam").stdout.strip(), "uid=1001(sam) gid=1001(sam) groups=1001(sam),999(docker)")
        self.assertEqual(self.line("group", "adm"), "adm:x:4:syslog")
        self.assertEqual(self.line("gshadow", "dev"), "dev:!:sam:lee")
        self.ok("usermod", "-aG", "sudo,dev", "sam")
        self.assertEqual(self.ok("groups", "sam").stdout.strip(), "sam : sam sudo docker dev")
        self.ok("usermod", "-r", "-G", "docker", "sam")
        self.assertEqual(self.ok("id", "-nG", "sam").stdout.strip(), "sam sudo dev")
        r = self.run_tool("usermod", "-a", "sam")
        self.assertEqual(r.returncode, 2)
        self.assertTrue(r.stderr.startswith("usermod: -a flag is ONLY allowed with the -G flag\nUsage: usermod"))

    def test_lock_unlock_expire(self):
        before = self.read("shadow")
        self.ok("usermod", "-L", "-e", "1", "sam")
        self.assertEqual(self.line("shadow", "sam"), "sam:!$y$j9T$abc$def:20000:0:99999:7::1:")
        self.ok("usermod", "-L", "lee")                  # already locked: no second "!"
        self.assertEqual(self.line("shadow", "lee"), "lee:!$6$xyz$uvw:20100:0:90:7:::")
        others = [l for l in self.read("shadow").splitlines() if not l.startswith("sam:")]
        self.assertEqual(others, [l for l in before.splitlines() if not l.startswith("sam:")])
        self.ok("usermod", "-U", "-e", "", "sam")
        self.assertEqual(self.line("shadow", "sam"), "sam:$y$j9T$abc$def:20000:0:99999:7:::")
        self.ok("useradd", "nopw")
        r = self.ok("usermod", "-U", "nopw")
        self.assertIn("unlocking the user's password would result in a passwordless account.", r.stderr)
        self.assertEqual(self.line("shadow", "nopw").split(":")[1], "!")

    def test_shell_comment_rename_and_no_changes(self):
        self.assertEqual(self.ok("usermod", "-s", "/bin/bash", "sam").stdout.strip(), "usermod: no changes")
        self.ok("usermod", "-s", "/usr/sbin/nologin", "-c", "Sam O.", "sam")
        self.assertEqual(self.line("passwd", "sam"), "sam:x:1001:1001:Sam O.:/home/sam:/usr/sbin/nologin")
        self.ok("usermod", "-l", "samuel", "-d", "/home/samuel", "-m", "sam")
        self.assertEqual(self.line("passwd", "samuel"), "samuel:x:1001:1001:Sam O.:/home/samuel:/usr/sbin/nologin")
        self.assertTrue((self.root / "home" / "samuel").is_dir())
        self.assertFalse((self.root / "home" / "sam").exists())
        self.assertEqual(self.line("group", "sudo"), "sudo:x:27:samuel")
        self.assertEqual(self.line("gshadow", "dev"), "dev:!:samuel:samuel,lee")
        self.assertTrue(self.line("shadow", "samuel").startswith("samuel:$y$"))

    def test_errors(self):
        self.fails(6, "usermod: user 'ghost' does not exist", "usermod", "-s", "/bin/sh", "ghost")
        self.fails(6, "usermod: group 'nope' does not exist", "usermod", "-G", "nope", "sam")
        self.fails(9, "usermod: user 'lee' already exists", "usermod", "-l", "lee", "sam")
        self.fails(4, "usermod: UID '1002' already exists", "usermod", "-u", "1002", "sam")
        self.fails(2, "Usage: usermod [options] LOGIN", "usermod", "sam")

    def test_subordinate_ranges(self):
        self.ok("usermod", "-v", "300000-365535", "-w", "300000-365535", "sam")
        self.assertIn("sam:300000:65536", self.read("subuid").splitlines())
        self.ok("usermod", "-V", "300000-365535", "sam")
        self.assertNotIn("sam:300000:65536", self.read("subuid").splitlines())


class UserdelAndGroupTests(AccountsRoot):
    def test_userdel(self):
        self.ok("useradd", "-m", "kim")
        self.ok("usermod", "-aG", "dev", "kim")
        r = self.ok("userdel", "-r", "kim")
        self.assertEqual(r.stderr.strip(), "userdel: kim mail spool (/var/mail/kim) not found")
        for f in ("passwd", "shadow", "group", "gshadow", "subuid", "subgid"):
            self.assertNotIn("kim", self.read(f), f)
        self.assertFalse((self.root / "home" / "kim").exists())
        self.assertEqual(self.line("group", "dev"), "dev:x:1050:sam,lee")
        self.fails(6, "userdel: user 'kim' does not exist", "userdel", "kim")
        self.ok("userdel", "lee")
        self.assertIsNone(self.line("group", "lee"))
        self.assertEqual(self.line("group", "docker"), "docker:x:999:")

    def test_groupadd_groupmod_groupdel(self):
        self.ok("groupadd", "ops")
        self.assertEqual(self.line("group", "ops"), "ops:x:1051:")
        self.assertEqual(self.line("gshadow", "ops"), "ops:!::")
        self.fails(9, "groupadd: group 'ops' already exists", "groupadd", "ops")
        self.ok("groupadd", "-f", "ops")
        self.fails(4, "groupadd: GID '1050' already exists", "groupadd", "-g", "1050", "qa")
        self.ok("groupadd", "-r", "svc")
        self.assertEqual(self.line("group", "svc"), "svc:x:997:")
        self.ok("groupmod", "-n", "operations", "-g", "2000", "ops")
        self.assertEqual(self.line("group", "operations"), "operations:x:2000:")
        self.assertEqual(self.line("gshadow", "operations"), "operations:!::")
        self.fails(9, "groupmod: group 'dev' already exists", "groupmod", "-n", "dev", "operations")
        self.ok("groupmod", "-g", "2001", "sam")                 # follows into passwd
        self.assertEqual(self.line("passwd", "sam"), "sam:x:1001:2001:Sam Ortiz,,,:/home/sam:/bin/bash")
        self.fails(8, "groupdel: cannot remove the primary group of user 'sam'", "groupdel", "sam")
        self.ok("groupdel", "operations")
        self.assertIsNone(self.line("group", "operations"))
        self.fails(6, "groupdel: group 'operations' does not exist", "groupdel", "operations")

    def test_gpasswd(self):
        r = self.ok("gpasswd", "-a", "sam", "docker")
        self.assertEqual(r.stdout.strip(), "Adding user sam to group docker")
        self.assertEqual(self.line("group", "docker"), "docker:x:999:lee,sam")
        self.assertEqual(self.line("gshadow", "docker"), "docker:!::lee,sam")
        r = self.ok("gpasswd", "-d", "lee", "docker")
        self.assertEqual(r.stdout.strip(), "Removing user lee from group docker")
        self.ok("gpasswd", "-d", "sam", "docker")
        self.assertEqual(self.line("group", "docker"), "docker:x:999:")      # no stray comma
        self.assertEqual(self.line("gshadow", "docker"), "docker:!::")
        self.fails(3, "gpasswd: user 'sam' is not a member of 'docker'", "gpasswd", "-d", "sam", "docker")
        self.fails(3, "gpasswd: user 'ghost' does not exist", "gpasswd", "-a", "ghost", "docker")
        self.fails(3, "gpasswd: group 'nope' does not exist in /etc/group", "gpasswd", "-a", "sam", "nope")
        self.ok("gpasswd", "-M", "lee,sam", "-A", "lee", "dev")
        self.assertEqual(self.line("group", "dev"), "dev:x:1050:lee,sam")
        self.assertEqual(self.line("gshadow", "dev"), "dev:!:lee:lee,sam")


class PasswordAgingTests(AccountsRoot):
    def test_passwd_status_lock_unlock(self):
        self.assertEqual(self.ok("passwd", "-S", "sam").stdout, "sam P 2024-10-04 0 99999 7 -1\n")
        rows = self.ok("passwd", "-S", "-a").stdout.splitlines()
        self.assertIn("root L 2024-03-18 0 99999 7 -1", rows)
        self.assertIn("lee L 2025-01-12 0 90 7 -1", rows)
        self.assertEqual(self.ok("passwd", "-l", "sam").stdout.strip(),
                         "passwd: password expiry information changed.")
        self.assertEqual(self.line("shadow", "sam"), "sam:!$y$j9T$abc$def:20000:0:99999:7:::")
        self.ok("passwd", "-u", "sam")
        self.assertEqual(self.line("shadow", "sam"), "sam:$y$j9T$abc$def:20000:0:99999:7:::")
        self.ok("passwd", "-d", "lee")
        self.assertEqual(self.ok("passwd", "-S", "lee").stdout.split()[1], "NP")
        self.ok("passwd", "-e", "sam")
        self.assertEqual(self.line("shadow", "sam").split(":")[2], "0")
        self.ok("useradd", "nopw")
        r = self.run_tool("passwd", "-u", "nopw")
        self.assertEqual(r.returncode, 3)
        self.assertIn("unlocking the password would result in a passwordless account.", r.stderr)
        self.fails(1, "passwd: user 'ghost' does not exist", "passwd", "-S", "ghost")
        self.fails(2, "mock: changing a password interactively is not supported (use -l, -u, -d, -e, -S, -n, -x, "
                      "-w, -i)", "passwd", "sam")

    def test_chage(self):
        out = self.ok("chage", "-l", "lee").stdout
        self.assertEqual(out, "Last password change\t\t\t\t\t: Jan 12, 2025\n"
                              "Password expires\t\t\t\t\t: Apr 12, 2025\n"
                              "Password inactive\t\t\t\t\t: never\n"
                              "Account expires\t\t\t\t\t\t: never\n"
                              "Minimum number of days between password change\t\t: 0\n"
                              "Maximum number of days between password change\t\t: 90\n"
                              "Number of days of warning before password expires\t: 7\n")
        self.assertIn("Password expires\t\t\t\t\t: never", self.ok("chage", "-l", "sam").stdout)
        self.ok("chage", "-d", "0", "-E", "2026-12-31", "-M", "90", "-I", "5", "sam")
        self.assertEqual(self.line("shadow", "sam"), "sam:$y$j9T$abc$def:0:0:90:7:5:20818:")
        out = self.ok("chage", "-l", "-i", "sam").stdout.splitlines()
        self.assertEqual(out[0], "Last password change\t\t\t\t\t: password must be changed")
        self.assertEqual(out[3], "Account expires\t\t\t\t\t\t: 2026-12-31")
        self.ok("chage", "-E", "-1", "sam")
        self.assertEqual(self.line("shadow", "sam").split(":")[7], "")
        self.fails(1, "chage: user 'ghost' does not exist in /etc/passwd", "chage", "-l", "ghost")
        self.fails(2, "chage: invalid date 'soon'", "chage", "-d", "soon", "sam")


class IdentityTests(AccountsRoot):
    def test_id_groups_getent(self):
        self.assertEqual(self.ok("id", "sam").stdout.strip(),
                         "uid=1001(sam) gid=1001(sam) groups=1001(sam),4(adm),27(sudo),1050(dev)")
        self.assertEqual(self.ok("id", "-u", "lee").stdout.strip(), "1002")
        self.assertEqual(self.ok("id", "-gn", "lee").stdout.strip(), "lee")
        self.assertEqual(self.ok("id", "-G", "lee").stdout.strip(), "1002 999 1050")
        self.assertEqual(self.ok("id", "1002").stdout.split()[0], "uid=1002(lee)")
        self.fails(1, "id: 'ghost': no such user", "id", "ghost")
        self.assertEqual(self.ok("groups", "sam", "lee").stdout, "sam : sam adm sudo dev\nlee : lee docker dev\n")
        self.assertEqual(self.ok("getent", "passwd", "lee", "33").stdout,
                         "lee:x:1002:1002:Lee Chen,,,:/home/lee:/bin/bash\n"
                         "www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin\n")
        self.assertEqual(self.ok("getent", "group", "docker").stdout, "docker:x:999:lee\n")
        self.assertEqual(self.ok("getent", "shadow", "lee").stdout, "lee:!$6$xyz$uvw:20100:0:90:7:::\n")
        self.assertEqual(len(self.ok("getent", "passwd").stdout.splitlines()), 7)
        r = self.run_tool("getent", "passwd", "ghost")
        self.assertEqual((r.returncode, r.stdout), (2, ""))
        self.fails(1, "Unknown database: nosuchdb", "getent", "nosuchdb")
        self.fails(1, "mock: getent database 'hosts' not supported", "getent", "hosts", "x")


class RootDetectionTests(unittest.TestCase):
    def test_lm_root_and_multicall(self):
        with tempfile.TemporaryDirectory(prefix="lm-acct-") as tmp:
            root = Path(tmp)
            (root / "sysroot" / "etc").mkdir(parents=True)
            (root / "sysroot" / "etc" / "passwd").write_text("root:x:0:0:root:/root:/bin/bash\n")
            (root / "sysroot" / "etc" / "group").write_text("root:x:0:\n")
            env = {k: v for k, v in os.environ.items() if not k.startswith("LM_")}
            env["LM_ROOT"] = str(root / "sysroot")
            r = subprocess.run([sys.executable, str(MOCKS / "accounts-mock"), "useradd", "ops"],
                               capture_output=True, text=True, env=env)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual((root / "sysroot" / "etc" / "passwd").read_text().splitlines()[-1],
                             "ops:x:1000:1000::/home/ops:/bin/sh")
            self.assertFalse((root / "sysroot" / "etc" / "shadow").exists())   # not created when absent


if __name__ == "__main__":
    unittest.main()
