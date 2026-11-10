"""Safety guards for LinuxMissions.

Levels run real commands on the player's machine, so a few host-destroying
commands are blocked. Checks look at the actual arguments (not substrings), so
`rm -rf /tmp/linuxmissions/...` inside the sandbox is allowed while `rm -rf /`
or `rm -rf ~` is not.
"""
from __future__ import annotations

import re
import shlex

try:
    from .ui import console
except ImportError:
    from ui import console

# Paths that must never be the target of a recursive rm/chmod/chown.
PROTECTED_PATHS = {
    "/", "/*", "~", "~/", "~/*", "$HOME", "${HOME}", "$HOME/", "$HOME/*", "${HOME}/", "${HOME}/*",
    "/bin", "/boot", "/dev", "/etc", "/home", "/lib", "/lib64", "/opt", "/proc", "/root",
    "/sbin", "/srv", "/sys", "/usr", "/var", "/tmp",
    "/Applications", "/Library", "/System", "/Users", "/Volumes", "/private",
}

RAW_PATTERNS = [
    (re.compile(r":\s*\(\s*\)\s*\{.*:\s*\|\s*:.*\}"), "fork bombs are not allowed"),
    (re.compile(r"\b(mkfs(\.\w+)?|mke2fs|mkswap|wipefs|sfdisk|fdisk|parted)\b.*\s/dev/"), "formatting or partitioning a real disk is not allowed"),
    (re.compile(r"\bdd\b.*\bof=/dev/(sd|nvme|hd|vd|disk|mmcblk)"), "writing to a raw disk is not allowed"),
    (re.compile(r">\s*/dev/(sd|nvme|hd|vd|disk|mmcblk)"), "writing to a raw disk is not allowed"),
    (re.compile(r"--no-preserve-root"), "--no-preserve-root is not allowed"),
]

WARN_PATTERNS = [re.compile(r"(^|[\s;&|(])sudo\s"), re.compile(r"\bpasswd\s+root\b"), re.compile(r"\buserdel\s+root\b")]

_SEGMENT_SPLIT = re.compile(r"&&|\|\||[;|&\n]")


def _tokens(segment: str) -> list[str]:
    try:
        return shlex.split(segment, posix=True)
    except ValueError:
        return segment.split()


def _check_segment(segment: str) -> str | None:
    tokens = _tokens(segment)
    while tokens and tokens[0] in ("sudo", "command", "builtin", "nohup", "time", "env"):
        tokens = tokens[1:]
    if not tokens:
        return None
    cmd, args = tokens[0].rsplit("/", 1)[-1], tokens[1:]
    flags = [a for a in args if a.startswith("-")]
    targets = [a if a in PROTECTED_PATHS else (a.rstrip("/") or "/") for a in args if not a.startswith("-")]
    recursive = any(
        f == "--recursive" or (not f.startswith("--") and ("r" in f or "R" in f)) for f in flags
    )

    if cmd == "rm" and recursive:
        for target in targets:
            if target in PROTECTED_PATHS:
                return f"`rm -r {target}` would delete files outside the sandbox"
    if cmd in ("chmod", "chown", "chgrp") and recursive:
        for target in targets[1:]:
            if target in PROTECTED_PATHS:
                return f"`{cmd} -R ... {target}` would change files outside the sandbox"
    return None


def validate_command(cmd: str) -> tuple[bool, str]:
    """Return (allowed, reason). allowed=False means block the command."""
    for pattern, reason in RAW_PATTERNS:
        if pattern.search(cmd):
            return False, f"Blocked: {reason} in LinuxMissions."
    for segment in _SEGMENT_SPLIT.split(cmd):
        reason = _check_segment(segment)
        if reason:
            return False, f"Blocked: {reason}."
    return True, ""


def warn_command(cmd: str) -> bool:
    """Print a warning for dangerous-but-allowed commands. Returns True if warning shown."""
    for pat in WARN_PATTERNS:
        if pat.search(cmd):
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
