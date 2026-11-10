"""Unit tests for the engine pieces that levels depend on.

Run: python3 -m unittest discover -s tests -v   (or scripts/test-levels-docker.sh --unit)
"""
from __future__ import annotations

import _thread
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from engine.engine import ShellSession, is_interactive_command, needs_more_input  # noqa: E402
from engine.runner import reset_sandbox, run_setup, run_validate  # noqa: E402
from engine.safety import validate_command  # noqa: E402


class SafetyTests(unittest.TestCase):
    def assertBlocked(self, cmd):
        self.assertFalse(validate_command(cmd)[0], cmd)

    def assertAllowed(self, cmd):
        self.assertTrue(validate_command(cmd)[0], cmd)

    def test_blocks_host_destruction(self):
        for cmd in ("rm -rf /", "rm -rf /*", "rm -fr ~", "rm -r -f $HOME", "sudo rm -rf /etc",
                    "cd x && rm -rf /usr/", "rm --recursive --force /", "chmod -R 777 /",
                    "chown -R root /home", ":(){ :|:& };:", "mkfs.ext4 /dev/sda1",
                    "dd if=/dev/zero of=/dev/sda", "rm -rf --no-preserve-root /"):
            self.assertBlocked(cmd)

    def test_allows_sandbox_work(self):
        for cmd in ("rm -rf /tmp/linuxmissions/module-1/level-1/old", "rm -rf old_logs/",
                    "rm -rf $SANDBOX/cache", "rm -f /tmp/x.txt", "chmod -R 755 webroot",
                    "rm -rf ./build", "grep -r 'rm -rf /' notes.txt", "echo '/' | rm -i a",
                    "dd if=/dev/zero of=disk.img bs=1M count=1", "mkdir mkfs_notes"):
            self.assertAllowed(cmd)


class InputTests(unittest.TestCase):
    def test_interactive_detection(self):
        for cmd in ("nano notes.txt", "vim a", "edit config.ini", "less app.log", "man ls", "top",
                    "crontab -e", "python3", "sudo visudo"):
            self.assertTrue(is_interactive_command(cmd), cmd)
        for cmd in ("cat a | less", "python3 script.py", "man ls | grep -A2 NAME", "crontab -l",
                    "echo nano", "ls > top.txt"):
            self.assertFalse(is_interactive_command(cmd), cmd)

    def test_needs_more_input(self):
        for text in ("cat > a.sh <<'EOF'", "cat > a <<EOF\nline", "if true; then", "for f in *; do",
                     "echo 'open", "ls |", "echo a \\", "while read l; do\necho $l"):
            self.assertTrue(needs_more_input(text), text)
        for text in ("ls -la", "cat > a <<EOF\nhi\nEOF", "if true; then echo y; fi",
                     "for f in *; do\necho $f\ndone", "echo 'done'", "echo a \\\\"):
            self.assertFalse(needs_more_input(text), text)


class ShellSessionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.sandbox = Path(self.tmp.name)
        self.shell = ShellSession(self.sandbox)
        self.shell.start()

    def tearDown(self):
        self.shell.close()
        self.tmp.cleanup()

    def test_state_persists(self):
        self.shell.capture("mkdir sub && cd sub && export LM_X=42")
        self.assertEqual(self.shell.capture("echo $LM_X"), "42")
        self.assertEqual(self.shell.cwd().name, "sub")

    def test_heredoc_writes_file(self):
        code, _ = self.shell._execute("cat > greet.sh <<'EOF'\n#!/bin/bash\necho \"Hello, $1!\"\nEOF")
        self.assertEqual(code, 0)
        self.assertEqual(self.shell.capture("bash greet.sh World"), "Hello, World!")

    def test_multiline_block(self):
        out = self.shell.capture("for i in 1 2 3; do\n  echo n$i\ndone")
        self.assertEqual(out.split(), ["n1", "n2", "n3"])

    def test_exit_code(self):
        self.assertEqual(self.shell._execute("false")[0], 1)
        self.assertEqual(self.shell._execute("true")[0], 0)

    def test_ctrl_c_stops_command_not_game(self):
        threading.Timer(1.0, _thread.interrupt_main).start()
        start = time.time()
        code, _ = self.shell._execute("sleep 30")
        self.assertLess(time.time() - start, 10)
        self.assertEqual(code, 130)
        self.assertEqual(self.shell.capture("echo alive"), "alive")


class RunnerTests(unittest.TestCase):
    def test_setup_with_background_process_does_not_hang(self):
        with tempfile.TemporaryDirectory() as level_dir, tempfile.TemporaryDirectory() as sb:
            level = Path(level_dir)
            (level / "setup.sh").write_text('#!/bin/bash\nbash -c "sleep 30" &\necho started\n')
            (level / "validate.sh").write_text('#!/bin/bash\necho "FAIL: nope"; exit 1\n')
            start = time.time()
            code, out = run_setup(level, Path(sb))
            self.assertLess(time.time() - start, 10)
            self.assertEqual((code, out), (0, "started"))
            self.assertEqual(run_validate(level, Path(sb)), (False, "FAIL: nope"))
            reset_sandbox(Path(sb))


if __name__ == "__main__":
    unittest.main()
