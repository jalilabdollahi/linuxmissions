"""Run a level's setup.sh / validate.sh / solution.sh safely.

Shared by the game engine and by scripts/test_levels.py so both behave the same.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

SETUP_TIMEOUT = 60
VALIDATE_TIMEOUT = 30
SOLUTION_TIMEOUT = 120


def _run_script(script: Path, sandbox: Path, timeout: int, cwd: Path | None = None) -> tuple[int, str]:
    """Run `bash script sandbox` and return (exit code, combined output).

    Output goes to a temp file instead of a pipe: a level that starts a
    background process would otherwise keep the pipe open and hang the caller.
    """
    env = {**os.environ, "SANDBOX": str(sandbox)}
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8", errors="replace") as out:
        try:
            result = subprocess.run(
                ["bash", str(script), str(sandbox)],
                stdin=subprocess.DEVNULL,
                stdout=out,
                stderr=subprocess.STDOUT,
                cwd=str(cwd) if cwd else None,
                env=env,
                timeout=timeout,
            )
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 124
        out.seek(0)
        text = out.read()
    if code == 124 and not text.strip():
        text = f"{script.name} timed out after {timeout}s"
    return code, text.strip()


def kill_sandbox_processes(sandbox: Path) -> None:
    """Stop background processes a level started inside its sandbox."""
    if shutil.which("pkill"):
        subprocess.run(["pkill", "-9", "-f", str(sandbox)], capture_output=True)


def reset_sandbox(sandbox: Path) -> None:
    kill_sandbox_processes(sandbox)
    if sandbox.exists():
        # Levels may leave read-only dirs behind; make them removable first.
        subprocess.run(["chmod", "-R", "u+rwx", str(sandbox)], capture_output=True)
        shutil.rmtree(sandbox, ignore_errors=True)
    sandbox.mkdir(parents=True, exist_ok=True)


def run_setup(level_path: Path, sandbox: Path) -> tuple[int, str]:
    script = level_path / "setup.sh"
    if not script.exists():
        return 0, ""
    return _run_script(script, sandbox, SETUP_TIMEOUT)


def run_validate(level_path: Path, sandbox: Path) -> tuple[bool, str]:
    script = level_path / "validate.sh"
    if not script.exists():
        return False, "No validate.sh found for this level."
    code, out = _run_script(script, sandbox, VALIDATE_TIMEOUT)
    return code == 0, out


def run_solution(level_path: Path, sandbox: Path) -> tuple[int, str]:
    script = level_path / "solution.sh"
    return _run_script(script, sandbox, SOLUTION_TIMEOUT, cwd=sandbox)
