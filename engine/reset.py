"""Level sandbox setup/teardown for LinuxMissions."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from .ui import console

SANDBOX_ROOT = Path("/tmp/linuxmissions")


def get_sandbox(level_id: str) -> Path:
    """Return the sandbox path for a level (e.g. /tmp/linuxmissions/module-1/level-1)."""
    return SANDBOX_ROOT / level_id


def prepare_level(level_path: Path, level_id: str) -> Path:
    """Tear down any existing sandbox and run the level's setup.sh."""
    sandbox = get_sandbox(level_id)

    # Clean old sandbox
    if sandbox.exists():
        shutil.rmtree(sandbox)
    sandbox.mkdir(parents=True, exist_ok=True)

    setup_script = level_path / "setup.sh"
    if setup_script.exists():
        result = subprocess.run(
            ["bash", str(setup_script), str(sandbox)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            console.print(f"[red]setup.sh error:[/red] {result.stderr.strip()}")
    else:
        console.print(f"[dim]No setup.sh for this level — sandbox is empty.[/dim]")

    return sandbox
