"""Level sandbox setup/teardown for LinuxMissions."""
from __future__ import annotations

from pathlib import Path

try:
    from .runner import reset_sandbox, run_setup
    from .ui import console
except ImportError:
    from runner import reset_sandbox, run_setup
    from ui import console

SANDBOX_ROOT = Path("/tmp/linuxmissions")


def get_sandbox(level_id: str) -> Path:
    """Return the sandbox path for a level (e.g. /tmp/linuxmissions/module-1/level-1)."""
    return SANDBOX_ROOT / level_id


def prepare_level(level_path: Path, level_id: str) -> Path:
    """Tear down any existing sandbox (and its processes) and run the level's setup.sh."""
    sandbox = get_sandbox(level_id)
    reset_sandbox(sandbox)

    if not (level_path / "setup.sh").exists():
        console.print("[dim]No setup.sh for this level — sandbox is empty.[/dim]")
        return sandbox

    code, output = run_setup(level_path, sandbox)
    if code != 0:
        console.print(f"[red]setup.sh failed ({code}):[/red] {output[-500:]}")
    return sandbox
