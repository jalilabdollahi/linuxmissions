"""Unit tests for the shared systemd mocks in mocks/systemd/
(systemctl, journalctl, systemd-analyze, timedatectl).

Run: python3 -m unittest tests.test_mocks_systemd -v   (or scripts/test-levels-docker.sh --unit)
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOCKS = REPO / "mocks" / "systemd"
TOOLS = ("systemctl", "journalctl", "systemd-analyze", "timedatectl")
NOW = "2026-11-10 03:10:00"


class MockRoot(unittest.TestCase):
    """A temp fake root with the tools copied in, the way a level's setup.sh does it."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="lm-sd-")
        self.root = Path(self.tmp.name)
        for t in TOOLS:
            shutil.copy(MOCKS / t, self.root / t)       # follows the symlink, like plain `cp`
        (self.root / ".lm").mkdir()
        (self.root / ".lm" / "now").write_text(NOW + "\n")
        (self.root / "etc" / "systemd" / "system").mkdir(parents=True)
        (self.root / "etc" / "hostname").write_text("web01\n")

    def tearDown(self):
        subprocess.run(["pkill", "-9", "-f", str(self.root)], capture_output=True)
        time.sleep(0.05)
        self.tmp.cleanup()

    def run_tool(self, tool, *args, env=None):
        e = {k: v for k, v in os.environ.items() if not k.startswith("LM_")}
        e.update(env or {})
        return subprocess.run([str(self.root / tool), *args], capture_output=True, text=True, env=e,
                              cwd=str(self.root), timeout=60)

    def sc(self, *args, **kw):
        return self.run_tool("systemctl", *args, **kw)

    def jc(self, *args, **kw):
        return self.run_tool("journalctl", *args, **kw)

    def write(self, rel, text, mode=None):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(textwrap.dedent(text).lstrip("\n"))
        if mode is not None:
            p.chmod(mode)
        return p

    def unit(self, name, text, where="etc/systemd/system"):
        return self.write(f"{where}/{name}", text)

    def script(self, rel, body):
        return self.write(rel, "#!/bin/sh\n" + textwrap.dedent(body).lstrip("\n"), 0o755)

    def wait_for(self, cond, timeout=10.0):
        end = time.time() + timeout
        while time.time() < end:
            if cond():
                return True
            time.sleep(0.05)
        return cond()

    def prop(self, unit, name):
        return self.sc("show", unit, "-P", name).stdout.strip()

    def alive(self, pid):
        try:
            os.kill(int(pid), 0)
        except (OSError, ValueError):
            return False
        r = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], capture_output=True, text=True)
        return bool(r.stdout.strip()) and not r.stdout.strip().startswith("Z")


class SystemctlLifecycleTests(MockRoot):
    def test_missing_executable_fails_with_203(self):
        self.unit("myapp.service", """
            [Unit]
            Description=MyApp API server
            [Service]
            ExecStart=/opt/myapp/bin/myapp --port 8080
            """)
        r = self.sc("start", "myapp")
        self.assertEqual(r.returncode, 0, r.stderr)    # Type=simple: the job succeeds, the process fails
        self.assertTrue(self.wait_for(lambda: self.sc("is-active", "myapp").stdout.strip() == "failed"))
        r = self.sc("is-active", "myapp")
        self.assertEqual((r.stdout.strip(), r.returncode), ("failed", 3))
        st = self.sc("status", "myapp")
        self.assertEqual(st.returncode, 3)
        self.assertIn("× myapp.service - MyApp API server", st.stdout)
        self.assertIn("Active: failed (Result: exit-code) since Tue 2026-11-10 03:10:00 UTC", st.stdout)
        self.assertIn("ExecStart=/opt/myapp/bin/myapp --port 8080 (code=exited, status=203/EXEC)", st.stdout)
        self.assertIn("Failed to locate executable /opt/myapp/bin/myapp: No such file or directory", st.stdout)
        self.assertEqual(self.prop("myapp", "ExecMainStatus"), "203")
        self.assertEqual(self.sc("is-failed", "myapp").returncode, 0)

    def test_unknown_unit_errors(self):
        r = self.sc("start", "nope")
        self.assertEqual(r.returncode, 5)
        self.assertEqual(r.stderr.strip(), "Failed to start nope.service: Unit nope.service not found.")
        r = self.sc("status", "nope.service")
        self.assertEqual((r.returncode, r.stderr.strip()), (4, "Unit nope.service could not be found."))
        r = self.sc("is-enabled", "nope")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Failed to get unit file state for nope.service", r.stderr)
        r = self.sc("is-active", "nope")
        self.assertEqual((r.stdout.strip(), r.returncode), ("inactive", 3))
        r = self.sc("frobnicate", "x")
        self.assertEqual((r.returncode, r.stderr.strip()), (1, "Unknown command verb 'frobnicate'."))
        r = self.sc("isolate", "rescue.target")
        self.assertIn("mock: systemctl isolate is not supported", r.stderr)
        r = self.sc("--user", "status")
        self.assertIn("mock: option --user not supported", r.stderr)

    def test_start_runs_process_and_stop_kills_it(self):
        self.script("opt/app/run", """
            echo "app up on $PORT"
            exec sleep 300
            """)
        self.unit("app.service", """
            [Unit]
            Description=App
            [Service]
            Environment=PORT=8080
            ExecStart=/opt/app/run
            """)
        self.assertEqual(self.sc("start", "app").returncode, 0)
        self.assertTrue(self.wait_for(lambda: self.prop("app", "SubState") == "running"))
        pid = self.prop("app", "MainPID")
        self.assertTrue(self.alive(pid))
        self.assertTrue(self.wait_for(lambda: "app up on 8080" in self.jc("-u", "app", "-o", "cat").stdout))
        st = self.sc("status", "app")
        self.assertEqual(st.returncode, 0)
        self.assertIn("● app.service - App", st.stdout)
        self.assertIn("Active: active (running) since", st.stdout)
        self.assertIn(f"Main PID: {pid}", st.stdout)
        self.assertIn("web01 run[", st.stdout)
        self.assertEqual(self.sc("stop", "app").returncode, 0)
        self.assertTrue(self.wait_for(lambda: not self.alive(pid)))
        self.assertEqual(self.sc("is-active", "app").stdout.strip(), "inactive")
        st = self.sc("status", "app").stdout
        self.assertIn("○ app.service - App", st)
        self.assertIn(f"Main PID: {pid} (code=killed, signal=TERM)", st)
        self.assertIn("Stopped app.service - App.", st)

    def test_type_simple_background_child_is_killed(self):
        # The script backgrounds itself with & and exits: systemd sees the main
        # process exit and cleans up the whole control group.
        self.script("opt/api/serve", f"""
            sleep 300 {self.root}/marker &
            exit 0
            """)
        self.unit("api.service", """
            [Service]
            ExecStart=/opt/api/serve
            """)
        self.sc("start", "api")
        self.assertTrue(self.wait_for(lambda: self.prop("api", "ActiveState") == "inactive"))
        time.sleep(0.3)
        r = subprocess.run(["pgrep", "-f", f"sleep 300 {self.root}/marker"], capture_output=True, text=True)
        self.assertEqual(r.stdout.strip(), "")

    def test_daemon_reload_warning_enable_disable(self):
        self.script("usr/local/bin/agent", "exec sleep 300\n")
        unit = self.unit("metrics-agent.service", """
            [Unit]
            Description=Metrics agent
            [Service]
            ExecStart=/usr/local/bin/agent
            """)
        self.sc("daemon-reload")
        r = self.sc("enable", "metrics-agent")
        self.assertEqual(r.returncode, 0)
        self.assertIn("The unit files have no installation config (WantedBy=, RequiredBy=, UpheldBy=,", r.stderr)
        self.assertEqual(self.sc("is-enabled", "metrics-agent").stdout.strip(), "static")
        unit.write_text(unit.read_text() + "\n[Install]\nWantedBy=multi-user.target\n")
        r = self.sc("status", "metrics-agent")
        self.assertIn("changed on disk. Run 'systemctl daemon-reload' to reload units.", r.stderr)
        self.assertIn("# Warning: metrics-agent.service changed on disk", self.sc("cat", "metrics-agent").stdout)
        r = self.sc("enable", "--now", "metrics-agent")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "Created symlink /etc/systemd/system/multi-user.target.wants/"
                         "metrics-agent.service → /etc/systemd/system/metrics-agent.service.")
        link = self.root / "etc/systemd/system/multi-user.target.wants/metrics-agent.service"
        self.assertTrue(link.is_symlink())
        self.assertEqual(os.readlink(link), "/etc/systemd/system/metrics-agent.service")
        self.assertNotIn("changed on disk", self.sc("status", "metrics-agent").stderr)   # enable reloads
        self.assertTrue(self.wait_for(lambda: self.prop("metrics-agent", "SubState") == "running"))
        r = self.sc("is-enabled", "metrics-agent")
        self.assertEqual((r.stdout.strip(), r.returncode), ("enabled", 0))
        r = self.sc("disable", "--now", "metrics-agent")
        self.assertEqual(r.stdout.strip(), 'Removed "/etc/systemd/system/multi-user.target.wants/'
                         'metrics-agent.service".')
        self.assertFalse(link.is_symlink())
        r = self.sc("is-enabled", "metrics-agent")
        self.assertEqual((r.stdout.strip(), r.returncode), ("disabled", 1))
        self.assertEqual(self.sc("is-active", "metrics-agent").stdout.strip(), "inactive")
        self.assertIn("preset: enabled", self.sc("status", "metrics-agent").stdout)

    def test_restart_policy_and_start_limit(self):
        self.script("opt/q/consumer", "echo boom; exit 1\n")
        self.unit("queue.service", """
            [Unit]
            Description=Queue consumer
            [Service]
            ExecStart=/opt/q/consumer
            Restart=on-failure
            RestartSec=50ms
            """)
        self.sc("start", "queue")
        self.assertTrue(self.wait_for(lambda: self.prop("queue", "Result") == "start-limit-hit", 15))
        self.assertEqual(self.prop("queue", "NRestarts"), "5")
        self.assertEqual(self.prop("queue", "ActiveState"), "failed")
        log = self.jc("-u", "queue", "-o", "cat").stdout
        self.assertIn("queue.service: Main process exited, code=exited, status=1/FAILURE", log)
        self.assertIn("queue.service: Scheduled restart job, restart counter is at 5.", log)
        self.assertIn("queue.service: Start request repeated too quickly.", log)
        self.assertEqual(log.count("boom"), 5)
        r = self.sc("start", "queue")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Job for queue.service failed because start of the service was attempted too often.",
                      r.stderr)
        self.sc("reset-failed", "queue")
        self.assertEqual(self.sc("is-active", "queue").stdout.strip(), "inactive")

    def test_restart_always_restarts_clean_exit_but_no_does_not(self):
        self.script("opt/w/job", "echo tick\nexit 0\n")
        self.unit("w.service", """
            [Service]
            ExecStart=/opt/w/job
            Restart=on-failure
            """)
        self.sc("start", "w")
        self.assertTrue(self.wait_for(lambda: self.prop("w", "ActiveState") == "inactive"))
        time.sleep(0.3)
        self.assertEqual(self.prop("w", "NRestarts"), "0")
        self.assertEqual(self.prop("w", "Result"), "success")
        self.unit("w2.service", """
            [Unit]
            StartLimitBurst=3
            [Service]
            ExecStart=/opt/w/job
            Restart=always
            RestartSec=0
            """)
        self.sc("start", "w2")
        self.assertTrue(self.wait_for(lambda: self.prop("w2", "Result") == "start-limit-hit", 15))
        self.assertEqual(self.prop("w2", "NRestarts"), "3")

    def test_oneshot_failure_and_remain_after_exit(self):
        self.unit("backup.service", """
            [Unit]
            Description=Nightly backup
            [Service]
            Type=oneshot
            ExecStart=/bin/sh -c 'echo backing up; exit 3'
            """)
        r = self.sc("start", "backup")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(r.stderr.splitlines()[0],
                         "Job for backup.service failed because the control process exited with error code.")
        self.assertIn('See "systemctl status backup.service" and "journalctl -xeu backup.service" for details.',
                      r.stderr)
        self.assertIn("(code=exited, status=3/NOTIMPLEMENTED)", self.sc("status", "backup").stdout)
        self.unit("setup.service", """
            [Unit]
            Description=One-time setup
            [Service]
            Type=oneshot
            RemainAfterExit=yes
            ExecStart=/bin/true
            """)
        self.assertEqual(self.sc("start", "setup").returncode, 0)
        st = self.sc("status", "setup")
        self.assertEqual(st.returncode, 0)
        self.assertIn("Active: active (exited)", st.stdout)
        self.assertIn("Finished setup.service - One-time setup.", st.stdout)

    def test_working_directory_and_user_errors(self):
        self.write("etc/passwd", "root:x:0:0:root:/root:/bin/bash\n")
        self.unit("wd.service", """
            [Service]
            WorkingDirectory=/srv/missing
            ExecStart=/bin/true
            """)
        self.unit("usr.service", """
            [Service]
            User=ghost
            ExecStart=/bin/true
            """)
        self.sc("start", "wd", "usr")
        self.assertTrue(self.wait_for(lambda: self.prop("usr", "ActiveState") == "failed"))
        self.assertTrue(self.wait_for(lambda: self.prop("wd", "ActiveState") == "failed"))
        self.assertIn("status=200/CHDIR", self.sc("status", "wd").stdout)
        self.assertIn("status=217/USER", self.sc("status", "usr").stdout)

    def test_reload_keeps_main_pid_restart_changes_it(self):
        self.script("opt/api/server", f"""
            trap 'echo "config v2 loaded" >> {self.root}/api.log' HUP
            echo "config v1 loaded" >> {self.root}/api.log
            while :; do sleep 0.1; done
            """)
        self.unit("api.service", """
            [Unit]
            Description=API
            [Service]
            ExecStart=/opt/api/server
            ExecReload=/bin/kill -HUP $MAINPID
            """)
        self.sc("start", "api")
        self.assertTrue(self.wait_for(lambda: (self.root / "api.log").exists()))
        pid = self.prop("api", "MainPID")
        r = self.sc("reload", "api")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(self.wait_for(lambda: "v2" in (self.root / "api.log").read_text()))
        self.assertEqual(self.prop("api", "MainPID"), pid)
        self.assertIn("Reloaded api.service - API.", self.jc("-u", "api", "-o", "cat").stdout)
        self.sc("reload-or-restart", "api")
        self.assertEqual(self.prop("api", "MainPID"), pid)
        self.sc("restart", "api")
        self.assertTrue(self.wait_for(lambda: self.prop("api", "MainPID") not in ("0", pid)))
        self.unit("plain.service", "[Service]\nExecStart=/bin/sleep 300\n")
        r = self.sc("reload", "plain")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(r.stderr.strip(),
                         "Failed to reload plain.service: Job type reload is not applicable for unit plain.service.")


class UnitFileTests(MockRoot):
    def test_dropins_need_execstart_reset(self):
        self.script("opt/vendor/agent", "while :; do sleep 1; done\n")
        self.unit("vendor-agent.service", """
            [Unit]
            Description=Vendor agent
            [Service]
            ExecStart=/opt/vendor/agent --old
            """, where="usr/lib/systemd/system")
        self.write("etc/systemd/system/vendor-agent.service.d/override.conf", """
            [Service]
            Environment=LEVEL=debug
            ExecStart=/opt/vendor/agent --new
            """)
        self.sc("daemon-reload")
        r = self.sc("start", "vendor-agent")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Unit vendor-agent.service has a bad unit file setting.", r.stderr)
        st = self.sc("status", "vendor-agent").stdout
        self.assertIn("Loaded: bad-setting (Reason: Unit vendor-agent.service has a bad unit file setting.)", st)
        self.assertIn("Drop-In: /etc/systemd/system/vendor-agent.service.d\n             └─override.conf",
                      st)
        self.assertIn("Service has more than one ExecStart= setting",
                      self.jc("-u", "vendor-agent", "-o", "cat").stdout)
        self.write("etc/systemd/system/vendor-agent.service.d/override.conf", """
            [Service]
            Environment=LEVEL=debug
            ExecStart=
            ExecStart=/opt/vendor/agent --new
            """)
        self.sc("daemon-reload")
        self.assertEqual(self.sc("start", "vendor-agent").returncode, 0)
        cat = self.sc("cat", "vendor-agent").stdout
        self.assertTrue(cat.startswith("# /usr/lib/systemd/system/vendor-agent.service\n"))
        self.assertIn("\n# /etc/systemd/system/vendor-agent.service.d/override.conf\n", cat)
        ex = self.prop("vendor-agent", "ExecStart")
        self.assertIn("path=/opt/vendor/agent ; argv[]=/opt/vendor/agent --new ;", ex)
        self.assertEqual(self.prop("vendor-agent", "Environment"), "LEVEL=debug")
        self.assertEqual(self.prop("vendor-agent", "DropInPaths"),
                         "/etc/systemd/system/vendor-agent.service.d/override.conf")
        self.assertEqual(self.prop("vendor-agent", "FragmentPath"), "/usr/lib/systemd/system/vendor-agent.service")
        self.assertTrue(self.wait_for(lambda: self.prop("vendor-agent", "SubState") == "running"))
        pid = self.prop("vendor-agent", "MainPID")
        ps = subprocess.run(["ps", "-o", "args=", "-p", pid], capture_output=True, text=True).stdout
        self.assertIn("--new", ps)

    def test_relative_execstart_is_rejected(self):
        self.unit("rel.service", "[Service]\nExecStart=./run.sh\n")
        r = self.sc("start", "rel")
        self.assertEqual(r.returncode, 1)
        log = self.jc("-u", "rel", "-o", "cat").stdout
        self.assertIn("Neither a valid executable name nor an absolute path: ./run.sh", log)

    def test_environment_files(self):
        self.script("opt/billing/run", 'echo "DB_HOST=$DB_HOST DB_PORT=$DB_PORT"\nexec sleep 300\n')
        self.write("etc/billing/env", "DB_HOST=db-prod\r\nDB_PORT=\"5433\"\r\n# comment\n")
        self.unit("billing.service", """
            [Service]
            Environment=DB_HOST=wrong DB_PORT=1
            EnvironmentFile=-/etc/biling/env
            EnvironmentFile=/etc/billing/env
            ExecStart=/opt/billing/run
            """)
        self.sc("start", "billing")
        self.assertTrue(self.wait_for(lambda: "DB_HOST=" in self.jc("-u", "billing", "-o", "cat").stdout))
        self.assertIn("DB_HOST=db-prod DB_PORT=5433", self.jc("-u", "billing", "-o", "cat").stdout)
        self.assertEqual(self.prop("billing", "Environment"), "DB_HOST=wrong DB_PORT=1")
        self.assertIn("/etc/biling/env (ignore_errors=yes)", self.sc("show", "billing", "-p", "EnvironmentFiles").stdout)
        self.sc("stop", "billing")
        self.unit("billing.service", """
            [Service]
            EnvironmentFile=/etc/biling/env
            ExecStart=/opt/billing/run
            """)
        self.sc("daemon-reload")
        r = self.sc("start", "billing")
        self.assertEqual(r.returncode, 1)
        self.assertIn("failed because of unavailable resources or another system error", r.stderr)
        self.assertEqual(self.prop("billing", "Result"), "resources")
        self.assertIn("Failed to load environment files: No such file or directory",
                      self.jc("-u", "billing", "-o", "cat").stdout)

    def test_mask_unmask_and_list_unit_files(self):
        self.unit("legacy-sync.service", """
            [Unit]
            Description=Legacy sync
            [Service]
            ExecStart=/bin/sleep 300
            [Install]
            WantedBy=multi-user.target
            """, where="usr/lib/systemd/system")
        self.unit("local.service", "[Service]\nExecStart=/bin/true\n")
        r = self.sc("mask", "legacy-sync")
        self.assertEqual(r.stdout.strip(), "Created symlink /etc/systemd/system/legacy-sync.service → /dev/null.")
        self.assertEqual(os.readlink(self.root / "etc/systemd/system/legacy-sync.service"), "/dev/null")
        r = self.sc("start", "legacy-sync")
        self.assertEqual((r.returncode, r.stderr.strip()),
                         (1, "Failed to start legacy-sync.service: Unit legacy-sync.service is masked."))
        self.assertEqual(self.sc("is-enabled", "legacy-sync").stdout.strip(), "masked")
        r = self.sc("mask", "local")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(r.stderr.strip(), "Failed to mask unit: File /etc/systemd/system/local.service already exists.")
        files = self.sc("list-unit-files", "--type=service").stdout.splitlines()
        self.assertEqual(files[0].split(), ["UNIT", "FILE", "STATE", "PRESET"])
        self.assertIn(["legacy-sync.service", "masked", "enabled"], [l.split() for l in files])
        self.assertIn(["local.service", "static", "-"], [l.split() for l in files])
        self.assertEqual(files[-1], "2 unit files listed.")
        r = self.sc("unmask", "legacy-sync")
        self.assertEqual(r.stdout.strip(), 'Removed "/etc/systemd/system/legacy-sync.service".')
        self.assertEqual(self.sc("is-enabled", "legacy-sync").stdout.strip(), "disabled")

    def test_set_property_writes_control_dropin(self):
        self.unit("reports.service", "[Service]\nExecStart=/bin/sleep 300\n")
        self.assertEqual(self.prop("reports", "MemoryMax"), "infinity")
        r = self.sc("set-property", "reports", "MemoryMax=1536M")
        self.assertEqual(r.returncode, 0, r.stderr)
        drop = self.root / "etc/systemd/system.control/reports.service.d/50-MemoryMax.conf"
        self.assertEqual(drop.read_text(),
                         "# This is a drop-in unit file extension, created via \"systemctl set-property\"\n"
                         "# or an equivalent operation. Do not edit.\n[Service]\nMemoryMax=1610612736\n")
        self.assertEqual(self.prop("reports", "MemoryMax"), "1610612736")
        self.assertNotIn("changed on disk", self.sc("status", "reports").stderr)
        r = self.sc("set-property", "reports", "ExecStart=/bin/false")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Cannot set property ExecStart, or unknown property.", r.stderr)

    def test_show_value_and_restart_settings(self):
        self.unit("c.service", """
            [Unit]
            StartLimitIntervalSec=60
            StartLimitBurst=3
            [Service]
            ExecStart=/bin/sleep 300
            Restart=on-failure
            RestartSec=5
            LimitNOFILE=65536
            """)
        out = self.sc("show", "c", "-p", "Restart,RestartUSec,StartLimitBurst,StartLimitIntervalUSec,LimitNOFILE")
        self.assertEqual(out.stdout.splitlines(), ["Restart=on-failure", "RestartUSec=5s", "LimitNOFILE=65536",
                                                   "StartLimitIntervalUSec=1min", "StartLimitBurst=3"])
        self.assertEqual(self.sc("show", "c", "-p", "Restart", "--value").stdout, "on-failure\n")

    def test_default_target(self):
        self.assertEqual(self.sc("get-default").stdout.strip(), "graphical.target")
        r = self.sc("set-default", "multi-user.target")
        self.assertEqual(r.stdout.strip(), "Created symlink /etc/systemd/system/default.target → "
                         "/usr/lib/systemd/system/multi-user.target.")
        self.assertEqual(os.readlink(self.root / "etc/systemd/system/default.target"),
                         "/usr/lib/systemd/system/multi-user.target")
        self.assertEqual(self.sc("get-default").stdout.strip(), "multi-user.target")
        r = self.sc("set-default", "nope.target")
        self.assertEqual(r.stderr.strip(), "Failed to set default target: Unit file nope.target does not exist.")

    def test_list_units_and_failed(self):
        self.write(".lm/systemd/units/broken.service.state",
                   "ActiveState=failed\nSubState=failed\nResult=exit-code\nExecMainPID=4242\n"
                   "ExecMainCode=exited\nExecMainStatus=1\nStateChangeTimestamp=2026-11-10 02:55:00\n")
        self.unit("broken.service", "[Unit]\nDescription=Broken thing\n[Service]\nExecStart=/bin/false\n")
        self.unit("idle.service", "[Unit]\nDescription=Idle\n[Service]\nExecStart=/bin/true\n")
        out = self.sc("--failed").stdout.splitlines()
        self.assertEqual(out[0].split(), ["UNIT", "LOAD", "ACTIVE", "SUB", "DESCRIPTION"])
        self.assertTrue(out[1].startswith("● broken.service loaded failed failed Broken thing"))
        self.assertIn("1 loaded units listed. Pass --all to see loaded but inactive units, too.", out)
        st = self.sc("status", "broken").stdout
        self.assertIn("Active: failed (Result: exit-code) since Tue 2026-11-10 02:55:00 UTC; 15min ago", st)
        self.assertIn("Main PID: 4242 (code=exited, status=1/FAILURE)", st)
        names = [l.split()[0] for l in self.sc("list-units", "--all", "--type=service", "--plain",
                                                  "--no-legend").stdout.splitlines()]
        self.assertEqual(names, ["broken.service", "idle.service"])


class DependencyTests(MockRoot):
    def setUp(self):
        super().setUp()
        self.script("opt/app", f"""
            [ -e {self.root}/proxy-up ] || {{ echo "cannot reach db-proxy"; exit 1; }}
            exec sleep 300
            """)
        self.unit("db-proxy.service", f"""
            [Unit]
            Description=DB proxy
            After=app.service
            [Service]
            Type=oneshot
            RemainAfterExit=yes
            ExecStart=/bin/touch {self.root}/proxy-up
            ExecStop=/bin/rm -f {self.root}/proxy-up
            [Install]
            WantedBy=multi-user.target
            """)
        self.unit("app.service", """
            [Unit]
            Description=App
            Requires=db-proxy.service
            After=db-proxy.service
            [Service]
            ExecStart=/opt/app
            [Install]
            WantedBy=multi-user.target
            """)
        self.sc("enable", "app", "db-proxy")

    def test_boot_reports_ordering_cycle(self):
        r = self.sc("mock-boot", "multi-user.target")
        self.assertEqual(r.returncode, 1)
        self.assertIn("app.service: Found ordering cycle on db-proxy.service/start", r.stdout)
        self.assertIn("Job db-proxy.service/start deleted to break ordering cycle starting with app.service/start",
                      r.stdout)
        self.assertIn("Found ordering cycle", self.jc("-p", "err", "-o", "cat").stdout)

    def test_boot_orders_and_stop_propagates(self):
        p = self.root / "etc/systemd/system/db-proxy.service"
        p.write_text(p.read_text().replace("After=app.service\n", ""))
        r = self.sc("mock-boot", "multi-user.target")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        lines = r.stdout.splitlines()
        self.assertLess(lines.index("[  OK  ] Finished db-proxy.service - DB proxy."),
                        lines.index("[  OK  ] Started app.service - App."))
        self.assertLess(lines.index("[  OK  ] Started app.service - App."),
                        lines.index("[  OK  ] Reached target multi-user.target - Multi-User System."))
        self.assertTrue(self.wait_for(lambda: self.prop("app", "SubState") == "running"))
        self.sc("stop", "db-proxy")
        self.assertEqual(self.sc("is-active", "app").stdout.strip(), "inactive")
        self.assertFalse((self.root / "proxy-up").exists())
        tree = self.sc("list-dependencies", "app").stdout.splitlines()
        self.assertEqual(tree[0], "app.service")
        self.assertIn("○ └─db-proxy.service", tree)
        rev = self.sc("list-dependencies", "--reverse", "db-proxy").stdout.splitlines()
        self.assertIn("○ ├─app.service", rev)

    def test_start_pulls_in_required_unit_first(self):
        p = self.root / "etc/systemd/system/db-proxy.service"
        p.write_text(p.read_text().replace("After=app.service\n", ""))
        self.sc("daemon-reload")
        self.assertEqual(self.sc("start", "app").returncode, 0)
        self.assertEqual(self.sc("is-active", "db-proxy").stdout.strip(), "active")
        self.assertTrue(self.wait_for(lambda: self.prop("app", "SubState") == "running"))


FIXTURE = [
    {"__REALTIME_TIMESTAMP": "2026-11-09 23:00:00", "_BOOT_ID": "a" * 32, "PRIORITY": "6",
     "SYSLOG_IDENTIFIER": "myapp", "_PID": "100", "_SYSTEMD_UNIT": "myapp.service", "MESSAGE": "started, error_rate=0"},
    {"__REALTIME_TIMESTAMP": "2026-11-09 23:30:00", "_BOOT_ID": "a" * 32, "PRIORITY": "3",
     "SYSLOG_IDENTIFIER": "myapp", "_PID": "100", "_SYSTEMD_UNIT": "myapp.service", "MESSAGE": "db down"},
    {"__REALTIME_TIMESTAMP": "2026-11-10 02:00:01", "_BOOT_ID": "b" * 32, "PRIORITY": "6", "_TRANSPORT": "kernel",
     "SYSLOG_IDENTIFIER": "kernel", "MESSAGE": "Linux version 6.8.0-45-generic"},
    {"__REALTIME_TIMESTAMP": "2026-11-10 02:05:00", "_BOOT_ID": "b" * 32, "PRIORITY": "2",
     "SYSLOG_IDENTIFIER": "myapp", "_PID": "200", "_SYSTEMD_UNIT": "myapp.service", "MESSAGE": "Out of memory"},
    {"__REALTIME_TIMESTAMP": "2026-11-10 02:50:00", "_BOOT_ID": "b" * 32, "PRIORITY": "4",
     "SYSLOG_IDENTIFIER": "nginx", "_PID": "300", "_SYSTEMD_UNIT": "nginx.service",
     "MESSAGE": "upstream myapp ERROR slow"},
    {"__REALTIME_TIMESTAMP": "1794279600000000", "_BOOT_ID": "b" * 32, "PRIORITY": "6",
     "SYSLOG_IDENTIFIER": "systemd", "_PID": "1", "UNIT": "myapp.service", "MESSAGE": "Started myapp.service - MyApp."},
    {"__REALTIME_TIMESTAMP": "2026-11-10 03:05:00", "_BOOT_ID": "b" * 32, "PRIORITY": "6",
     "SYSLOG_IDENTIFIER": "payment", "_PID": "400", "_SYSTEMD_UNIT": "payment@eu.service", "MESSAGE": "eu tick"},
]


class JournalctlTests(MockRoot):
    def setUp(self):
        super().setUp()
        lines = [json.dumps(dict(e, _HOSTNAME="web01")) for e in FIXTURE]
        self.write("var/log/journal/system.json", "\n".join(lines) + "\n")

    def msgs(self, *args, **kw):
        r = self.jc("-o", "cat", *args, **kw)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout.splitlines()

    def test_short_format_and_boot_separator(self):
        out = self.jc("-u", "myapp").stdout.splitlines()
        self.assertEqual(out[0], "Nov 09 23:00:00 web01 myapp[100]: started, error_rate=0")
        self.assertIn("-- Boot " + "b" * 32 + " --", out)
        self.assertIn("Nov 10 03:00:00 web01 systemd[1]: Started myapp.service - MyApp.", out)
        iso = self.jc("-u", "myapp", "-o", "short-iso", "-n", "1").stdout.strip()
        self.assertEqual(iso, "2026-11-10T03:00:00+00:00 web01 systemd[1]: Started myapp.service - MyApp.")

    def test_priority_filters(self):
        self.assertEqual(self.msgs("-p", "err"), ["db down", "Out of memory"])
        self.assertEqual(self.msgs("-p", "3"), ["db down", "Out of memory"])
        self.assertEqual(self.msgs("-p", "warning..err"), ["db down", "upstream myapp ERROR slow"])
        r = self.jc("-p", "bogus")
        self.assertEqual((r.returncode, r.stderr.strip()), (1, "Unknown log level bogus"))

    def test_time_filters(self):
        self.assertEqual(self.msgs("--since", "2026-11-10 02:04", "--until", "02:51"),
                         ["Out of memory", "upstream myapp ERROR slow"])
        self.assertEqual(self.msgs("--since", "-15min"), ["Started myapp.service - MyApp.", "eu tick"])
        self.assertEqual(self.msgs("-S", "25 min ago", "-U", "-10min"),
                         ["upstream myapp ERROR slow", "Started myapp.service - MyApp."])
        self.assertEqual(len(self.msgs("--since", "today")), 5)
        self.assertEqual(self.msgs("--until", "yesterday"), [])
        self.assertEqual(self.msgs("--since", "@1794276240"), ["Out of memory", "upstream myapp ERROR slow",
                                                               "Started myapp.service - MyApp.", "eu tick"])
        r = self.jc("--since", "yesterday 10:00")
        self.assertEqual((r.returncode, r.stderr.strip()), (1, "Failed to parse timestamp: yesterday 10:00"))

    def test_local_time_zone(self):
        self.write("etc/timezone", "Asia/Tehran\n")
        # epoch stamps are shown in local time ...
        out = self.jc("-u", "myapp", "-n", "1").stdout.strip()
        self.assertEqual(out, "Nov 10 06:30:00 web01 systemd[1]: Started myapp.service - MyApp.")
        # ... and readable fixture stamps, --since and the frozen clock are local time too
        utc = self.jc("-p", "err", "-b", "-1", "--utc", "-o", "short-iso").stdout.strip()
        self.assertEqual(utc, "2026-11-09T20:00:00+00:00 web01 myapp[100]: db down")
        self.assertEqual(self.msgs("--since", "-1h"),
                         ["upstream myapp ERROR slow", "eu tick", "Started myapp.service - MyApp."])
        self.assertEqual(self.msgs("--since", "02:00", "--until", "02:30"), ["Linux version 6.8.0-45-generic",
                                                                             "Out of memory"])

    def test_boots_and_kernel(self):
        boots = self.jc("--list-boots").stdout.splitlines()
        self.assertEqual(boots[0].split()[:3], ["IDX", "BOOT", "ID"])
        self.assertEqual(boots[1].split()[:2], ["-1", "a" * 32])
        self.assertEqual(boots[2].split()[:2], ["0", "b" * 32])
        self.assertEqual(self.msgs("-b", "-1"), ["started, error_rate=0", "db down"])
        self.assertEqual(self.msgs("-b", "a" * 32), ["started, error_rate=0", "db down"])
        self.assertEqual(len(self.msgs("-b")), 5)
        self.assertEqual(self.jc("-k").stdout.strip(), "Nov 10 02:00:01 web01 kernel: Linux version 6.8.0-45-generic")
        r = self.jc("-b", "-5")
        self.assertEqual(r.returncode, 1)

    def test_grep_lines_reverse_units_and_output(self):
        self.assertEqual(self.msgs("-g", "error"), ["started, error_rate=0", "upstream myapp ERROR slow"])
        self.assertEqual(self.msgs("-g", "ERROR"), ["upstream myapp ERROR slow"])
        self.assertEqual(self.msgs("-n", "2"), ["Started myapp.service - MyApp.", "eu tick"])
        self.assertEqual(self.msgs("-n", "2", "-r"), ["eu tick", "Started myapp.service - MyApp."])
        self.assertEqual(self.msgs("-u", "payment"), [])
        self.assertEqual(self.msgs("-u", "payment@eu"), ["eu tick"])
        self.assertEqual(self.msgs("-u", "payment*"), ["eu tick"])
        self.assertEqual(self.msgs("_PID=300"), ["upstream myapp ERROR slow"])
        self.assertEqual(self.msgs("-t", "nginx"), ["upstream myapp ERROR slow"])
        j = json.loads(self.jc("-o", "json", "-n", "1").stdout)
        self.assertEqual(j["MESSAGE"], "eu tick")
        self.assertEqual(j["__REALTIME_TIMESTAMP"], "1794279900000000")
        self.assertEqual(self.jc("-u", "nothing").stdout.strip(), "-- No entries --")
        self.assertEqual(self.jc("-q", "-u", "nothing").stdout, "")
        self.assertIn("mock: option -f not supported", self.jc("-f").stderr)

    def test_systemctl_status_shows_journal(self):
        self.unit("myapp.service", "[Unit]\nDescription=MyApp\n[Service]\nExecStart=/bin/true\n")
        st = self.sc("status", "myapp", "-n", "2").stdout
        self.assertTrue(st.rstrip().endswith("Nov 10 02:05:00 web01 myapp[200]: Out of memory\n"
                                             "Nov 10 03:00:00 web01 systemd[1]: Started myapp.service - MyApp."), st)


class AnalyzeAndTimedateTests(MockRoot):
    def test_blame_critical_chain_time(self):
        r = self.run_tool("systemd-analyze", "blame")
        self.assertEqual(r.returncode, 1)
        self.assertIn("Bootup is not yet finished", r.stderr)
        self.write(".lm/boot-timing", """
            firmware 4000
            loader 1200
            kernel 2300
            initrd 3100
            userspace 150000
            systemd-networkd.service 2900 3110
            systemd-networkd-wait-online.service 3120 148500 after=systemd-networkd.service
            network-online.target 148500 148500 after=systemd-networkd-wait-online.service
            snapd.seeded.service 5000 35002
            app.service 148540 148870 after=network-online.target,snapd.seeded.service
            multi-user.target 148871 148871 after=app.service,snapd.seeded.service
            """)
        self.run_tool("systemctl", "set-default", "multi-user.target")
        blame = self.run_tool("systemd-analyze", "blame").stdout.splitlines()
        self.assertEqual(blame[0], "2min 25.380s systemd-networkd-wait-online.service")
        self.assertEqual(blame[1], "     30.002s snapd.seeded.service")
        self.assertEqual(blame[2], "       330ms app.service")
        chain = self.run_tool("systemd-analyze", "critical-chain").stdout.splitlines()
        self.assertEqual(chain[3:], [
            "multi-user.target @2min 28.871s",
            "└─app.service @2min 28.540s +330ms",
            "  └─network-online.target @2min 28.500s",
            "    └─systemd-networkd-wait-online.service @3.120s +2min 25.380s",
            "      └─systemd-networkd.service @2.900s +210ms",
        ])
        t = self.run_tool("systemd-analyze", "time").stdout.splitlines()
        self.assertEqual(t[0], "Startup finished in 4s (firmware) + 1.200s (loader) + 2.300s (kernel) + "
                               "3.100s (initrd) + 2min 30s (userspace) = 2min 40.600s ")
        self.assertEqual(t[1], "multi-user.target reached after 2min 28.871s in userspace.")

    def test_verify(self):
        self.unit("x.service", """
            [Unit]
            Requires=nope.service
            [Service]
            ExecStar=/bin/true
            ExecStart=/opt/none --flag
            """)
        r = self.run_tool("systemd-analyze", "verify", "x.service")
        self.assertEqual(r.returncode, 1)
        self.assertIn("/etc/systemd/system/x.service:4: Unknown key name 'ExecStar' in section 'Service', ignoring.",
                      r.stderr)
        self.assertIn("x.service: Command /opt/none is not executable: No such file or directory", r.stderr)
        self.assertIn("x.service: Failed to create nope.service/start: Unit nope.service not found.", r.stderr)
        self.write("report-api.service", "[Service]\nExecStart=/bin/true\n[Install]\nWantedBy=multi-user.target\n")
        r = self.run_tool("systemd-analyze", "verify", "./report-api.service")
        self.assertEqual((r.returncode, r.stderr), (0, ""))

    def test_timedatectl(self):
        self.write("etc/timezone", "Asia/Tehran\n")
        out = self.run_tool("timedatectl").stdout.splitlines()
        self.assertEqual(out[0], "               Local time: Tue 2026-11-10 03:10:00 +0330")
        self.assertEqual(out[1], "           Universal time: Mon 2026-11-09 23:40:00 UTC")
        self.assertEqual(out[3], "                Time zone: Asia/Tehran (+0330, +0330)")
        r = self.run_tool("timedatectl", "set-timezone", "Mars/Base")
        self.assertEqual((r.returncode, r.stderr.strip()),
                         (1, "Failed to set time zone: Invalid or not installed time zone 'Mars/Base'"))
        self.assertEqual(self.run_tool("timedatectl", "set-timezone", "Europe/Berlin").returncode, 0)
        self.assertEqual((self.root / "etc/timezone").read_text(), "Europe/Berlin\n")
        self.assertIn("Time zone: Europe/Berlin (CET, +0100)", self.run_tool("timedatectl").stdout)


class RootDetectionTests(unittest.TestCase):
    def test_tools_in_bin_use_parent_and_lm_root_overrides(self):
        with tempfile.TemporaryDirectory(prefix="lm-sd-") as tmp:
            root = Path(tmp)
            (root / "bin").mkdir()
            shutil.copy(MOCKS / "systemctl", root / "bin" / "systemctl")
            (root / "etc/systemd/system").mkdir(parents=True)
            (root / "etc/systemd/system/a.service").write_text("[Service]\nExecStart=/bin/true\n")
            env = {k: v for k, v in os.environ.items() if not k.startswith("LM_")}
            r = subprocess.run([str(root / "bin/systemctl"), "list-unit-files", "--no-legend"],
                               capture_output=True, text=True, env=env)
            self.assertEqual(r.stdout.split()[:2], ["a.service", "static"])
            other = root / "other"
            (other / "etc/systemd/system").mkdir(parents=True)
            env["LM_ROOT"] = str(other)
            r = subprocess.run([str(root / "bin/systemctl"), "list-unit-files", "--type=service", "--no-legend"],
                               capture_output=True, text=True, env=env)
            self.assertEqual(r.stdout.strip(), "")
            r = subprocess.run([sys.executable, str(MOCKS / "systemd-mock"), "systemctl", "get-default"],
                               capture_output=True, text=True, env=env)
            self.assertEqual(r.stdout.strip(), "graphical.target")


if __name__ == "__main__":
    unittest.main()
