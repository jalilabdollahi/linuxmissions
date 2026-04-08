"""Safety guards for LinuxMissions."""
from __future__ import annotations

from .ui import console

# Commands that are blocked because they could destroy the host system
BLOCKED_PATTERNS = [
    "rm -rf /",
    "rm -rf /*",
    ":(){ :|:& };:",   # fork bomb
    "> /dev/sda",
    "dd if=/dev/zero of=/dev/",
    "mkfs",
    "chmod -R 777 /",
    "chmod 777 /",
    "chown -R root /",
]

WARN_PATTERNS = [
    "sudo rm",
    "sudo chmod",
    "sudo dd",
    "passwd root",
    "userdel root",
]


def validate_command(cmd: str) -> tuple[bool, str]:
    """Return (allowed, reason). allowed=False means block the command."""
    lower = cmd.strip().lower()
    for pat in BLOCKED_PATTERNS:
        if pat in lower:
            return False, f"Blocked: '{pat}' is not allowed in LinuxMissions."
    return True, ""


def warn_command(cmd: str) -> bool:
    """Print a warning for dangerous-but-allowed commands. Returns True if warning shown."""
    lower = cmd.strip().lower()
    for pat in WARN_PATTERNS:
        if pat in lower:
            console.print(
                f"[yellow]⚠  Warning: '{cmd}' could affect the real system outside the sandbox.[/yellow]"
            )
            return True
    return False


def print_safety_info() -> None:
    console.print(
        "[dim]LinuxMissions runs in a sandbox under /tmp/linuxmissions/. "
        "Some destructive host-level commands are blocked.[/dim]"
    )
