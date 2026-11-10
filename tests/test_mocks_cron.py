"""Unit tests for the cron mocks in mocks/cron/ (crontab, cron-run, cron-expand,
run-parts, systemd-analyze calendar, cronlib, oncalendar).

Run: python3 -m unittest tests.test_mocks_cron -v   (or scripts/test-levels-docker.sh --unit)
Works on Linux and macOS; comparisons with the real run-parts, systemd-analyze
and crontab run only where those exist.
"""
from __future__ import annotations

import datetime as dt
import io
import json
import os
import platform
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CRON = REPO / "mocks" / "cron"
sys.path.insert(0, str(CRON))

import cronlib  # noqa: E402
import oncalendar  # noqa: E402

D = dt.datetime


def fires(line, start, end, system=False):
    e = cronlib.parse_line(line, system=system)
    return [t for t, _ in cronlib.expand([e], start, end)]


class ParserTests(unittest.TestCase):
    def test_fields_names_ranges_steps(self):
        e = cronlib.parse_line("*/15 9-16 * jan,MAR mon-Fri /bin/check")
        self.assertEqual(sorted(e.minute), [0, 15, 30, 45])
        self.assertEqual(sorted(e.hour), list(range(9, 17)))
        self.assertEqual(sorted(e.month), [1, 3])
        self.assertEqual(sorted(e.dow), [1, 2, 3, 4, 5])
        self.assertEqual(e.command, "/bin/check")
        self.assertEqual(e.schedule, "*/15 9-16 * jan,MAR mon-Fri")
        self.assertEqual(sorted(cronlib.parse_line("1-30/10,45 * * * * x").minute), [1, 11, 21, 45])
        self.assertEqual(sorted(cronlib.parse_line("*/50 * * * * x").minute), [0, 50])

    def test_sunday_is_0_and_7(self):
        self.assertEqual(sorted(cronlib.parse_line("0 0 * * 7 x").dow), [0, 7])
        self.assertEqual(sorted(cronlib.parse_line("0 0 * * sun x").dow), [0, 7])
        self.assertEqual(sorted(cronlib.parse_line("0 0 * * 5-7 x").dow), [0, 5, 6, 7])

    def test_reversed_range_selects_nothing(self):
        e = cronlib.parse_line("5-1 * * * * x")
        self.assertEqual(e.minute, frozenset())
        self.assertEqual(fires("5-1 * * * * x", D(2024, 4, 8), D(2024, 4, 9)), [])

    def test_errors_like_debian_crontab(self):
        cases = {
            "61 * * * * x\n": '"f":0: bad minute',
            "* 24 * * * x\n": '"f":0: bad hour',
            "* * 0 * * x\n": '"f":0: bad day-of-month',
            "* * * 13 * x\n": '"f":0: bad month',
            "* * * * 8 x\n": '"f":0: bad day-of-week',
            "5/10 * * * * x\n": '"f":0: bad minute',        # step without a range
            "*/0 * * * * x\n": '"f":0: bad minute',
            "* * * * monday x\n": '"f":0: bad day-of-week',  # only 3-letter names
            "@foo x\n": '"f":0: bad time specifier',
            "* * * * * * x\n": '"f":0: bad command',        # six fields
            "MAILTO=\n": '"f":0: bad minute',               # empty unquoted value is no env line
            "# ok\n\n0 3 * * * a\nfoo bar\n": '"f":3: bad minute',
            "* * * *\n": '"f":1: bad day-of-week',
        }
        for text, msg in cases.items():
            with self.subTest(text=text):
                self.assertEqual(cronlib.check_install(text, "f"),
                                 [msg, "errors in crontab file, can't install."])

    def test_accepts(self):
        for text in ("* * * * * \n", "@reboot /x\n", "@annually x\n", "@midnight x\n",
                     "  # indented comment\n", "MAILTO=\"\"\n", "0 0 1 jan-dec/3 * x\n",
                     "# last line comment without newline"):
            with self.subTest(text=text):
                self.assertEqual(cronlib.check_install(text, "f"), [])

    def test_missing_newline(self):
        self.assertEqual(cronlib.check_install("0 3 * * * x", "f"),
                         ["new crontab file is missing newline before EOF, can't install."])

    def test_step_warning(self):
        tab = cronlib.parse_crontab("1-5/9 * * * * y\n")
        self.assertEqual(tab.warnings, ["Warning: Step size 9 higher than possible maximum of 4"])
        self.assertTrue(tab.ok)

    def test_env_lines(self):
        tab = cronlib.parse_crontab(
            'A=1\nB = two words  \nC="quoted value "\n D=\'x\'\n0 1 * * * first\nA=changed\n0 2 * * * second\n'
            'E = "a" junk\n')
        self.assertEqual(tab.env["B"], "two words")
        self.assertEqual(tab.env["C"], "quoted value")   # cron trims trailing blanks even inside quotes
        self.assertEqual(tab.env["D"], "x")
        first, second = tab.entries
        self.assertEqual(first.env["A"], "1")
        self.assertEqual(second.env["A"], "changed")
        self.assertNotIn("E", tab.env)  # trailing junk after a quoted value: not an env line
        self.assertTrue(tab.errors)     # ... so it is parsed as a (bad) job line

    def test_system_crontab_user_field(self):
        tab = cronlib.parse_crontab("SHELL=/bin/sh\n17 * * * * root cd / && run-parts --report /etc/cron.hourly\n",
                                    system=True)
        e = tab.entries[0]
        self.assertEqual((e.user, e.command, e.schedule), ("root", "cd / && run-parts --report /etc/cron.hourly",
                                                           "17 * * * *"))
        self.assertEqual(cronlib.check_install("0 3 * * * root\n", "f", system=True)[0], '"f":1: bad command')

    def test_macros(self):
        self.assertEqual(fires("@weekly x", D(2024, 4, 1), D(2024, 4, 30)),
                         [D(2024, 4, 7), D(2024, 4, 14), D(2024, 4, 21), D(2024, 4, 28)])
        self.assertEqual(fires("@monthly x", D(2024, 1, 15), D(2024, 4, 15)),
                         [D(2024, 2, 1), D(2024, 3, 1), D(2024, 4, 1)])
        self.assertEqual(len(fires("@hourly x", D(2024, 4, 8), D(2024, 4, 9))), 24)
        self.assertEqual(fires("@yearly x", D(2023, 6, 1), D(2025, 6, 1)), [D(2024, 1, 1), D(2025, 1, 1)])
        self.assertEqual(fires("@reboot x", D(2024, 1, 1), D(2024, 2, 1)), [])
        self.assertTrue(cronlib.parse_line("@reboot x").reboot)


class SemanticsTests(unittest.TestCase):
    def test_day_or_rule(self):
        # 03:00 on the 1st OR on any Sunday (April 2024: 1st is a Monday)
        got = fires("0 3 1 * 0 x", D(2024, 4, 1), D(2024, 5, 2))
        self.assertEqual([t.day for t in got if t.month == 4], [1, 7, 14, 21, 28])
        self.assertIn(D(2024, 5, 1, 3), got)

    def test_star_step_counts_as_star(self):
        # */2 in day-of-month starts with '*': AND, not OR -> odd days that are Mondays
        got = fires("0 2 */2 * 1 x", D(2024, 4, 1), D(2024, 5, 1))
        self.assertEqual([t.day for t in got], [1, 15, 29])

    def test_star_dom_and_restricted_dow(self):
        got = fires("0 3 * * 1-5 x", D(2024, 4, 6), D(2024, 4, 13))   # Sat..Fri
        self.assertEqual([t.day for t in got], [8, 9, 10, 11, 12])

    def test_business_hours(self):
        got = fires("*/15 9-16 * * 1-5 true", D(2024, 4, 8), D(2024, 4, 9))
        self.assertEqual((len(got), got[0], got[-1]), (32, D(2024, 4, 8, 9), D(2024, 4, 8, 16, 45)))

    def test_window_bounds_and_order(self):
        tab = cronlib.parse_crontab("30 * * * * b\n0,30 * * * * a\n")
        runs = cronlib.expand(tab.entries, D(2024, 4, 8, 1, 30), D(2024, 4, 8, 2, 30))
        self.assertEqual([(t.strftime("%H:%M"), e.command) for t, e in runs],
                         [("01:30", "b"), ("01:30", "a"), ("02:00", "a")])
        self.assertEqual(fires("* * * * * x", D(2024, 4, 8, 0, 0, 30), D(2024, 4, 8, 0, 3)),
                         [D(2024, 4, 8, 0, 1), D(2024, 4, 8, 0, 2)])

    def test_feb_29(self):
        self.assertEqual(fires("0 0 29 2 * x", D(2023, 1, 1), D(2025, 1, 1)), [D(2024, 2, 29)])

    def test_percent(self):
        self.assertEqual(cronlib.split_command("date +%F"), ("date +", "F\n"))
        self.assertEqual(cronlib.split_command(r"date +\%F-\%H"), ("date +%F-%H", None))
        self.assertEqual(cronlib.split_command("mail -s hi ops%line one%line two"),
                         ("mail -s hi ops", "line one\nline two\n"))
        self.assertEqual(cronlib.split_command(r"cat %a\%b%"), ("cat ", "a%b\n"))
        self.assertEqual(cronlib.split_command("x %"), ("x ", None))
        self.assertEqual(cronlib.split_command(r"a\\%b"), ("a\\", "b\n"))

    def test_header(self):
        h = cronlib.make_header("c.txt", D(2024, 4, 8, 14, 30))
        self.assertEqual(h.splitlines()[1], "# (c.txt installed on Mon Apr  8 14:30:00 2024)")
        self.assertEqual(cronlib.strip_header(h + "# mine\n0 1 * * * x\n"), "# mine\n0 1 * * * x\n")
        self.assertEqual(cronlib.strip_header("0 1 * * * x\n"), "0 1 * * * x\n")

    def test_name_rules(self):
        for name, ok in (("backup", True), ("db-backup_2", True), ("db-backup.sh", False),
                         ("old.conf.dpkg-old", False), (".hidden", False), ("Upper", True)):
            self.assertEqual(cronlib.valid_crond_name(name), ok, name)
            self.assertEqual(cronlib.valid_runparts_name(name), ok, name)
        self.assertFalse(cronlib.valid_runparts_name("50-disk.sh", lsbsysinit=True))
        self.assertTrue(cronlib.valid_runparts_name("foo.bar-baz", lsbsysinit=True))
        self.assertFalse(cronlib.valid_runparts_name("foo.bar-baz.dpkg-old", lsbsysinit=True))
        self.assertTrue(cronlib.valid_runparts_name("rotate", regex=r"^ro"))

    def test_anacrontab(self):
        env, jobs, errors = cronlib.parse_anacrontab(
            "SHELL=/bin/sh\n# p d id cmd\n1 10 build.nightly /opt/build.sh --all\n@weekly 5 weekly run-parts x\n"
            "x 5 bad cmd\n1 5 build.nightly dup\n")
        self.assertEqual(env, {"SHELL": "/bin/sh"})
        self.assertEqual([(j["period"], j["delay"], j["job_id"], j["command"]) for j in jobs],
                         [(1, 10, "build.nightly", "/opt/build.sh --all"), (7, 5, "weekly", "run-parts x")])
        self.assertEqual(len(errors), 2)


def tool(name, *args, env=None, input=None, cwd=None):
    return subprocess.run([sys.executable, str(CRON / name), *args], capture_output=True, text=True,
                          env=env, input=input, cwd=cwd, timeout=60)


class CrontabMockTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="lm-crontab-test."))
        self.spool = self.tmp / "spool"
        self.env = dict(os.environ, LM_CRON_SPOOL=str(self.spool), LM_CRON_USER="deploy",
                        LM_CRON_NOW="2024-04-08 14:30")
        self.env.pop("LM_CRON_PRIVILEGED", None)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def ct(self, *args, input=None, env=None):
        return tool("crontab", *args, env=env or self.env, input=input, cwd=str(self.tmp))

    def test_list_install_remove(self):
        r = self.ct("-l")
        self.assertEqual((r.returncode, r.stderr), (1, "no crontab for deploy\n"))
        (self.tmp / "c.txt").write_text("MAILTO=ops@example.com\n*/5 * * * * /bin/true\n")
        r = self.ct("c.txt")
        self.assertEqual((r.returncode, r.stdout, r.stderr), (0, "", ""))
        stored = (self.spool / "deploy").read_text()
        self.assertTrue(stored.startswith("# DO NOT EDIT THIS FILE - edit the master and reinstall.\n"
                                          "# (c.txt installed on Mon Apr  8 14:30:00 2024)\n"))
        self.assertEqual(stat.S_IMODE((self.spool / "deploy").stat().st_mode), 0o600)
        r = self.ct("-l")
        self.assertEqual((r.returncode, r.stdout), (0, "MAILTO=ops@example.com\n*/5 * * * * /bin/true\n"))
        r = self.ct("-r")
        self.assertEqual(r.returncode, 0)
        self.assertFalse((self.spool / "deploy").exists())
        self.assertEqual(self.ct("-r").stderr, "no crontab for deploy\n")

    def test_refuses_bad_file_and_keeps_old(self):
        self.ct("-", input="0 1 * * * old\n")
        (self.tmp / "bad.txt").write_text("0 1 * * * ok\n61 * * * * x\n")
        r = self.ct("bad.txt")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(r.stderr, '"bad.txt":1: bad minute\nerrors in crontab file, can\'t install.\n')
        self.assertEqual(self.ct("-l").stdout, "0 1 * * * old\n")
        r = self.ct(input="0 2 * * * no newline")       # no argument: reads stdin
        self.assertEqual(r.stderr, "new crontab file is missing newline before EOF, can't install.\n")
        r = self.ct("-n", "-", input="0 3 * * * fine\n")
        self.assertEqual((r.returncode, r.stderr), (0, "The syntax of the crontab file was successfully checked.\n"))
        self.assertEqual(self.ct("-l").stdout, "0 1 * * * old\n")
        r = self.ct("missing.txt")
        self.assertEqual((r.returncode, r.stderr), (1, "missing.txt: No such file or directory\n"))

    def test_user_option(self):
        r = self.ct("-u", "alice", "-l")
        self.assertEqual((r.returncode, r.stderr), (1, "must be privileged to use -u\n"))
        self.assertEqual(self.ct("-u", "deploy", "-l").stderr, "no crontab for deploy\n")
        env = dict(self.env, LM_CRON_PRIVILEGED="1")
        r = self.ct("-u", "alice", "-", input="@daily /x\n", env=env)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.ct("-u", "alice", "-l", env=env).stdout, "@daily /x\n")

    def test_usage_errors(self):
        r = self.ct("-l", "-r")
        self.assertEqual(r.returncode, 1)
        self.assertTrue(r.stderr.startswith("crontab: usage error: only one operation permitted\nusage:\tcrontab"))
        r = self.ct("-z")
        self.assertTrue(r.stderr.startswith("crontab: invalid option -- 'z'\ncrontab: usage error: unrecognized option"))
        self.assertIn("no arguments permitted after this option", self.ct("-l", "x").stderr)

    def test_delete_prompt(self):
        self.ct("-", input="0 1 * * * x\n")
        r = self.ct("-i", "-r", input="n\n")
        self.assertEqual((r.returncode, r.stdout), (0, "crontab: really delete deploy's crontab? (y/n) "))
        self.assertTrue((self.spool / "deploy").exists())
        r = self.ct("-ir", input="maybe\ny\n")
        self.assertEqual(r.stderr, "Please enter Y or N: ")
        self.assertFalse((self.spool / "deploy").exists())

    def test_edit(self):
        editor = self.tmp / "ed.sh"
        editor.write_text("#!/bin/sh\nsleep 0.01\necho '10 4 * * * /opt/warm-cache' >> \"$1\"\n")
        editor.chmod(0o755)
        env = dict(self.env, EDITOR=str(editor), VISUAL="")
        r = self.ct("-e", env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stderr, "no crontab for deploy - using an empty one\ncrontab: installing new crontab\n")
        listed = self.ct("-l").stdout
        self.assertTrue(listed.startswith("# Edit this file to introduce tasks to be run by cron.\n"))
        self.assertTrue(listed.endswith("# m h  dom mon dow   command\n10 4 * * * /opt/warm-cache\n"))
        self.assertIn("/crontab installed on", (self.spool / "deploy").read_text().splitlines()[1])
        r = self.ct("-e", env=dict(self.env, EDITOR="true"))
        self.assertEqual((r.returncode, r.stderr), (0, "No modification made\n"))
        bad = self.tmp / "bad.sh"
        bad.write_text("#!/bin/sh\nsleep 0.01\necho '99 * * * * x' >> \"$1\"\n")
        bad.chmod(0o755)
        r = self.ct("-e", env=dict(self.env, EDITOR=str(bad)), input="n\n")
        self.assertEqual(r.returncode, 1)
        self.assertIn("bad minute\nerrors in crontab file, can't install.\n", r.stderr)
        self.assertIn("Do you want to retry the same edit? (y/n) ", r.stdout)
        self.assertRegex(r.stderr, r"crontab: edits left in .*/crontab\n$")
        self.assertTrue(self.ct("-l").stdout.endswith("10 4 * * * /opt/warm-cache\n"))

    def test_spool_required(self):
        env = dict(self.env)
        del env["LM_CRON_SPOOL"]
        r = self.ct("-l", env=env)
        self.assertEqual(r.returncode, 1)
        self.assertIn("LM_CRON_SPOOL", r.stderr)

    @unittest.skipUnless(platform.system() == "Linux" and platform.machine() in ("x86_64", "amd64")
                         and shutil.which("crontab") and os.path.exists("/usr/share/doc/cron"),
                         "needs Debian cron on x86_64 (arm64's real crontab mis-reports field errors: "
                         "char is unsigned there)")
    def test_matches_real_crontab_dry_run(self):
        for text in ("61 * * * * x\n", "0 3 * * 1-5 /x\n", "5/10 * * * * x\n", "@foo x\n", "# c\n\n* * * *\n",
                     "MAILTO=\n", "0 0 * * mon-fri x\n", "0 3 * * * x"):
            f = self.tmp / "f.txt"
            f.write_text(text)
            real = subprocess.run(["crontab", "-n", "f.txt"], capture_output=True, text=True, cwd=str(self.tmp))
            mine = self.ct("-n", "f.txt")
            self.assertEqual((mine.returncode, mine.stderr), (real.returncode, real.stderr), text)


class InstallAndRunTests(unittest.TestCase):
    def setUp(self):
        self.sb = Path(tempfile.mkdtemp(prefix="lm-cron-sb."))

    def tearDown(self):
        shutil.rmtree(self.sb, ignore_errors=True)

    def install(self, *args):
        r = subprocess.run(["bash", str(CRON / "install.sh"), str(self.sb), *args], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)

    def sh(self, cmd, env=None, input=None):
        return subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, cwd=str(self.sb),
                              env=env, input=input, timeout=120)

    def test_install_wrappers(self):
        self.install("--user", "deploy", "--now", "2024-04-08 14:30", "crontab", "cron-expand", "run-parts",
                     "systemd-analyze", "cron-run")
        for t in ("crontab", "cron-expand", "run-parts", "systemd-analyze", "cron-run"):
            self.assertTrue(os.access(self.sb / "bin" / t, os.X_OK), t)
        env = {k: v for k, v in os.environ.items() if not k.startswith("LM_CRON")}
        r = self.sh("printf '0 4 * * * /x\\n' | bin/crontab - && bin/crontab -l && head -2 var/spool/cron/crontabs/deploy",
                    env=env)
        self.assertEqual(r.stdout.splitlines(), ["0 4 * * * /x", "# DO NOT EDIT THIS FILE - edit the master and reinstall.",
                                                 "# (- installed on Mon Apr  8 14:30:00 2024)"])
        r = self.sh("LM_CRON_USER=alice bin/crontab -l", env=env)
        self.assertEqual(r.stderr, "no crontab for alice\n")
        r = self.sh("bin/cron-expand --days 1 -e '0 */6 * * * x'", env=env)
        self.assertEqual(r.stdout.split("\n")[0], "2024-04-08 18:00\t1\tx")

    def test_cron_run(self):
        self.install("--user", "deploy", "crontab", "cron-run")
        sb = self.sb
        (sb / "etc/cron.d").mkdir(parents=True)
        (sb / "etc/cron.daily").mkdir(parents=True)
        (sb / "out").mkdir()
        (sb / "etc/cron.d/report").write_text(f"MAILTO=\"\"\n0 1 * * * reporter echo report $LOGNAME >> {sb}/out/report.txt\n")
        (sb / "etc/cron.d/old.dpkg-old").write_text(f"* * * * * root echo never >> {sb}/out/never.txt\n")
        (sb / "etc/cron.d/broken").write_text("70 * * * * root echo bad\n")
        for name, mode in (("backup", 0o755), ("rotate.sh", 0o755), ("stats", 0o644)):
            p = sb / "etc/cron.daily" / name
            p.write_text(f"#!/bin/sh\necho {name} ran at $(date +%F) in $(pwd)\n")
            p.chmod(mode)
        tab = (f"MAILTO=ops@example.com\n"
               f"0 3 * * * echo \"hourly $(date +\\%F-\\%H\\%M) path=$PATH home=$HOME\" >> {sb}/out/log.txt\n"
               f"30 3 * * * cat > {sb}/out/stdin.txt %first%second\n"
               f"0 4 * * * echo to-mail; exit 3\n")
        env = {k: v for k, v in os.environ.items() if not k.startswith("LM_CRON")}
        r = self.sh("bin/crontab -", env=env, input=tab)
        self.assertEqual(r.returncode, 0, r.stderr)
        jsonl = sb / "runs.jsonl"
        r = self.sh(f"bin/cron-run --from '2024-04-08 00:00' --days 2 --jsonl {jsonl} --log {sb}/cron.log", env=env)
        self.assertEqual(r.returncode, 1, r.stderr)   # etc/cron.d/broken has a syntax error
        self.assertIn("(*system*) ERROR (Syntax error, this crontab file will be ignored)", r.stdout)
        self.assertIn("Apr  8 03:00:01 sandbox CRON[", r.stdout)
        log = (sb / "out/log.txt").read_text().splitlines()
        self.assertEqual(len(log), 2)
        # the clock shim directory comes first in PATH, then cron's default
        self.assertRegex(log[0], rf"^hourly 2024-04-08-0300 path=[^:]*cron-run-clock[^:]*:/usr/bin:/bin home={sb}$")
        self.assertTrue(log[1].startswith("hourly 2024-04-09-0300 "))
        env_seen = [x["env"]["PATH"] for x in [json.loads(line) for line in jsonl.read_text().splitlines()]][:1]
        self.assertEqual(env_seen, ["/usr/bin:/bin"])
        self.assertEqual((sb / "out/stdin.txt").read_text(), "first\nsecond\n")
        self.assertEqual((sb / "out/report.txt").read_text(), "report reporter\nreport reporter\n")
        self.assertFalse((sb / "out/never.txt").exists())
        runs = [json.loads(line) for line in jsonl.read_text().splitlines()]
        daily = [x for x in runs if x["source"] == "etc/cron.daily"]
        self.assertEqual([x["time"] for x in daily], ["2024-04-08 06:25", "2024-04-09 06:25"])
        self.assertEqual(daily[0]["output"],
                         f"{sb}/etc/cron.daily/backup:\nbackup ran at 2024-04-08 in /\n")   # rotate.sh: has a dot; stats: not executable
        mail = [x for x in runs if x["command"] == "echo to-mail; exit 3"]
        self.assertEqual([(x["exit"], x["mailed"], x["user"]) for x in mail], [(3, "ops@example.com", "deploy")] * 2)
        mbox = (sb / "var/mail/ops@example.com").read_text()
        self.assertIn("Subject: Cron <deploy@sandbox> echo to-mail; exit 3\n", mbox)
        self.assertIn("X-Cron-Env: <LOGNAME=deploy>\n", mbox)
        self.assertEqual(mbox.count("\nto-mail\n"), 2)
        self.assertTrue((sb / "var/mail/root").exists())          # cron.daily output went to root
        self.assertIn("(deploy) CMD (cat > ", (sb / "cron.log").read_text())
        r = self.sh("bin/cron-run --from '2024-04-08 00:00' --to '2024-04-08 04:00' --list", env=env)
        self.assertEqual([line.split("\t")[0] for line in r.stdout.splitlines()],
                         ["2024-04-08 01:00", "2024-04-08 03:00", "2024-04-08 03:30"])

    def test_cron_run_overlap_with_tick(self):
        self.install("cron-run")
        sb = self.sb
        job = sb / "slow.sh"
        job.write_text(f"#!/bin/sh\necho start $(date +%H:%M) $$ >> {sb}/slow.log\nsleep 1.5\n"
                       f"echo end $(date +%H:%M) $$ >> {sb}/slow.log\n")
        job.chmod(0o755)
        tabfile = sb / "tab"
        tabfile.write_text(f"* * * * * {job}\n")
        env = {k: v for k, v in os.environ.items() if not k.startswith("LM_CRON")}
        t0 = time.time()
        r = self.sh(f"bin/cron-run --root {sb} --no-periodic --crontab {tabfile}:deploy --from '2024-04-08 02:00' "
                    f"--to '2024-04-08 02:03' --tick 1 -q --jsonl {sb}/r.jsonl", env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.time() - t0, 15)
        recs = [json.loads(x) for x in (sb / "r.jsonl").read_text().splitlines()]
        self.assertEqual(sorted(x["time"][-5:] for x in recs), ["02:00", "02:01", "02:02"])
        lines = (sb / "slow.log").read_text().splitlines()
        starts = [x for x in lines if x.startswith("start")]
        self.assertEqual([x.split()[1] for x in starts], ["02:00", "02:01", "02:02"])
        self.assertLess(lines.index(starts[1]), lines.index([x for x in lines if x.startswith("end")][0]),
                        "with --tick the second run starts before the first one ends")
        r = self.sh(f"bin/cron-run --root {sb} --no-periodic --crontab {tabfile} --from '2024-04-08 02:00' "
                    f"--to '2024-04-08 02:02' -q --jsonl {sb}/seq.jsonl", env=env)
        recs = [json.loads(x) for x in (sb / "seq.jsonl").read_text().splitlines()]
        self.assertLessEqual(recs[0]["end"], recs[1]["start"])

    def test_cron_run_timeout_and_boot(self):
        self.install("cron-run")
        sb = self.sb
        (sb / "tab").write_text(f"@reboot echo booted >> {sb}/boot.txt\n0 5 * * * sleep 30\n")
        r = self.sh(f"bin/cron-run --crontab {sb}/tab --from '2024-04-08 00:00' --days 1 --boot --timeout 1 -q "
                    f"--jsonl {sb}/r.jsonl --no-periodic")
        self.assertEqual(r.returncode, 0, r.stderr)
        recs = [json.loads(x) for x in (sb / "r.jsonl").read_text().splitlines()]
        self.assertEqual([(x["time"], x["killed"]) for x in recs], [("2024-04-08 00:00", False), ("2024-04-08 05:00", True)])
        self.assertEqual((sb / "boot.txt").read_text(), "booted\n")


class RunPartsTests(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp(prefix="lm-runparts."))
        for name, mode in (("10-first", 0o755), ("20_second", 0o755), ("30.third", 0o755), ("40-noexec", 0o644),
                           ("Zeta", 0o755), ("abc", 0o755), ("50-disk.sh", 0o755), ("x.dpkg-old", 0o755),
                           ("60-motd", 0o755), ("foo.bar-baz", 0o755), ("y.dpkg-new", 0o755),
                           ("_a", 0o755), ("a_b", 0o755), ("a-b.c", 0o755), ("1.2-3", 0o755)):
            p = self.d / name
            p.write_text(f"#!/bin/sh\necho {name}\n")
            p.chmod(mode)
        (self.d / "subdir").mkdir()

    def tearDown(self):
        shutil.rmtree(self.d, ignore_errors=True)

    def test_listing_and_running(self):
        r = tool("run-parts", "--test", str(self.d))
        self.assertEqual([Path(x).name for x in r.stdout.split()], ["10-first", "20_second", "60-motd", "Zeta", "_a", "a_b", "abc"])
        r = tool("run-parts", "--list", str(self.d))
        self.assertIn("40-noexec", r.stdout)
        r = tool("run-parts", "--report", str(self.d))
        self.assertEqual(r.stdout.splitlines()[:2], [f"{self.d}/10-first:", "10-first"])
        r = tool("run-parts", "--test", "--lsbsysinit", str(self.d))
        names = [Path(x).name for x in r.stdout.split()]
        self.assertIn("foo.bar-baz", names)
        self.assertNotIn("50-disk.sh", names)
        self.assertNotIn("y.dpkg-new", names)
        self.assertEqual(tool("run-parts", "--test", "/nonexistent").returncode, 1)

    @unittest.skipUnless(os.path.exists("/usr/bin/run-parts") and platform.system() == "Linux", "needs the real run-parts")
    def test_matches_real_run_parts(self):
        for opts in (["--test"], ["--list"], ["--test", "--lsbsysinit"], ["--test", "--reverse"],
                     ["--test", "--regex=^[0-9]"]):
            real = subprocess.run(["/usr/bin/run-parts", *opts, str(self.d)], capture_output=True, text=True)
            mine = tool("run-parts", *opts, str(self.d))
            self.assertEqual(mine.stdout, real.stdout, opts)


class OnCalendarTests(unittest.TestCase):
    def setUp(self):
        self.old_tz = os.environ.get("TZ")
        os.environ["TZ"] = "UTC"
        time.tzset()

    def tearDown(self):
        if self.old_tz is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = self.old_tz
        time.tzset()

    def test_normalized_forms(self):
        cases = {
            "Mon-Fri 02:30": "Mon..Fri *-*-* 02:30:00",
            "Mon..Fri 2:30": "Mon..Fri *-*-* 02:30:00",
            "daily": "*-*-* 00:00:00",
            "weekly": "Mon *-*-* 00:00:00",
            "minutely": "*-*-* *:*:00",
            "quarterly": "*-01,04,07,10-01 00:00:00",
            "*:0/15": "*-*-* *:00/15:00",
            "Mon,Tue,Wed,Sat *-*-* 9..17:00": "Mon..Wed,Sat *-*-* 09..17:00:00",
            "Mon..Sun 1:2:3": "*-*-* 01:02:03",
            "*-*-* 0..10/3:00": "*-*-* 00..09/3:00:00",
            "*-02~01 12:00": "*-02~01 12:00:00",
            "24-04-08 06:00": "2024-04-08 06:00:00",
            "1:2:3.5": "*-*-* 01:02:03.500000",
            "12:00 UTC": "*-*-* 12:00:00 UTC",
        }
        for spec, norm in cases.items():
            self.assertEqual(oncalendar.normalize(spec), norm, spec)
        for bad in ("*-*-* 25:00", "Sat..Mon 00:00", "Mon..", "  daily", "", "*-13-01", "*-*-* 0/0:00", "*/2:00",
                    "Sun..Sat 1:00"):
            with self.assertRaises(ValueError, msg=bad):
                oncalendar.parse(bad)

    def test_next_elapse(self):
        base = dt.datetime(2024, 4, 8, 0, 0, tzinfo=dt.timezone.utc)   # a Monday
        got = [t.strftime("%a %Y-%m-%d %H:%M:%S") for t in oncalendar.next_elapse("Mon..Fri 02:30", base, 6)]
        self.assertEqual(got, ["Mon 2024-04-08 02:30:00", "Tue 2024-04-09 02:30:00", "Wed 2024-04-10 02:30:00",
                               "Thu 2024-04-11 02:30:00", "Fri 2024-04-12 02:30:00", "Mon 2024-04-15 02:30:00"])
        self.assertEqual(oncalendar.next_elapse("*-02~01 12:00", base)[0].strftime("%F"), "2025-02-28")
        self.assertEqual(oncalendar.next_elapse("Fri *-*-13", base)[0].strftime("%F"), "2024-09-13")
        self.assertEqual(oncalendar.next_elapse("daily", base)[0].strftime("%F %T"), "2024-04-09 00:00:00")

    def test_report_format(self):
        out = io.StringIO()
        rc = oncalendar.calendar_report(["Mon-Fri 02:30"], 2, dt.datetime(2024, 4, 8, tzinfo=dt.timezone.utc),
                                        now=dt.datetime(2024, 4, 8, 1, 0, tzinfo=dt.timezone.utc), out=out)
        self.assertEqual(rc, 0)
        self.assertEqual(out.getvalue(), "  Original form: Mon-Fri 02:30\n"
                                         "Normalized form: Mon..Fri *-*-* 02:30:00\n"
                                         "    Next elapse: Mon 2024-04-08 02:30:00 UTC\n"
                                         "       From now: 1h 30min left\n"
                                         "   Iteration #2: Tue 2024-04-09 02:30:00 UTC\n"
                                         "       From now: 1 day 1h left\n")
        err = io.StringIO()
        self.assertEqual(oncalendar.calendar_report(["*-*-* 25:00"], out=io.StringIO(), err=err), 1)
        self.assertEqual(err.getvalue(), "Failed to parse calendar specification '*-*-* 25:00': Invalid argument\n")
        r = tool("systemd-analyze", "status")
        self.assertEqual(r.returncode, 1)
        self.assertIn("mock:", r.stderr)

    @unittest.skipUnless(shutil.which("systemd-analyze") and platform.system() == "Linux",
                         "needs the real systemd-analyze")
    def test_matches_real_systemd_analyze(self):
        specs = ["Mon-Fri 02:30", "*:0/15", "weekly", "monthly", "semiannually", "Sat,Sun 10:00", "*-*-01 03:00",
                 "*-02~01 12:00", "*-*~03", "Fri *-*-13", "Mon,Tue 1:00", "Wed..Fri,Mon 1:00", "*:*:0/10",
                 "*-*-* 1..23/2:00", "*-*-* 25:00", "Sat..Mon 00:00", "2023..2025-01-01", "1:2:3.5",
                 "Mon *-*-* *:00", "*-*-* 02:30:60", "monday 1:00"]
        env = dict(os.environ, TZ="UTC", SYSTEMD_COLORS="0")
        for spec in specs:
            real = subprocess.run(["systemd-analyze", "calendar", "--iterations=3", "--base-time=2024-04-08 00:00:00",
                                   spec], capture_output=True, text=True, env=env)
            mine = tool("systemd-analyze", "calendar", "--iterations=3", "--base-time=2024-04-08 00:00:00", spec,
                        env=env)
            strip = lambda s: [x for x in s.splitlines() if "From now" not in x]  # noqa: E731
            self.assertEqual((mine.returncode, strip(mine.stdout), strip(mine.stderr)),
                             (real.returncode, strip(real.stdout), strip(real.stderr)), spec)


if __name__ == "__main__":
    unittest.main()
