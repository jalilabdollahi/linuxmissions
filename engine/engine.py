#!/usr/bin/env python3
"""LinuxMissions main game loop."""
from __future__ import annotations

import json
import os
import pty
import readline  # noqa: F401 — arrow keys & history in prompts
import re
import select
import shlex
import subprocess
import sys
import termios
import time
import uuid
from pathlib import Path

try:
    from engine.certificate import generate_certificate, save_certificate
    from engine.player import prompt_player_name
    from engine.reset import prepare_level, get_sandbox
    from engine.safety import validate_command, warn_command, print_safety_info
    from engine.ui import (
        console,
        render_markdown,
        show_guidance,
        show_help,
        show_mission_briefing,
        show_post_level_debrief,
        show_command_bar,
        show_continue_prompt,
        show_status,
        show_victory,
        show_welcome,
        show_module_completion,
        module_title,
    )
except ModuleNotFoundError:
    from certificate import generate_certificate, save_certificate
    from player import prompt_player_name
    from reset import prepare_level, get_sandbox
    from safety import validate_command, warn_command, print_safety_info
    from ui import (
        console,
        render_markdown,
        show_guidance,
        show_help,
        show_mission_briefing,
        show_post_level_debrief,
        show_command_bar,
        show_continue_prompt,
        show_status,
        show_victory,
        show_welcome,
        show_module_completion,
        module_title,
    )

REPO_ROOT = Path(__file__).resolve().parent.parent
PROGRESS_FILE = REPO_ROOT / "progress.json"
LEVELS_REGISTRY = REPO_ROOT / "levels.json"
BRACKETED_PASTE_RE = re.compile(r"\x1b\[\?2004[hl]|\[\?2004[hl]")
META_COMMANDS = ("help", "hint", "status", "objective", "reset", "skip", "quit", "exit", "validate")


class SandboxCompleter:
    """Readline completer for meta commands, shell commands, and sandbox paths."""

    def __init__(self) -> None:
        self.sandbox = Path.cwd()
        self.command_names = self._discover_commands()

    def set_sandbox(self, sandbox: Path) -> None:
        self.sandbox = sandbox

    def complete(self, text: str, state: int) -> str | None:
        if state == 0:
            self.matches = self._build_matches(text)
        try:
            return self.matches[state]
        except IndexError:
            return None

    def _build_matches(self, text: str) -> list[str]:
        buffer = readline.get_line_buffer()
        begidx = readline.get_begidx()
        if begidx == 0:
            return self._complete_command(text)
        return self._complete_path(text)

    def _complete_command(self, text: str) -> list[str]:
        candidates = set(META_COMMANDS) | self.command_names
        candidates.update(self._list_path_entries("", include_hidden=text.startswith(".")))
        return sorted(candidate for candidate in candidates if candidate.startswith(text))

    def _complete_path(self, text: str) -> list[str]:
        include_hidden = text.startswith(".") or "/." in text
        return self._list_path_entries(text, include_hidden=include_hidden)

    def _list_path_entries(self, text: str, include_hidden: bool) -> list[str]:
        raw = text or ""
        expanded = Path(raw).expanduser()
        if raw.endswith("/"):
            base_dir = self._resolve_path(expanded)
            prefix = raw
            partial = ""
        else:
            parent = expanded.parent if raw else Path(".")
            base_dir = self._resolve_path(parent)
            prefix = "" if not raw else ("" if str(parent) == "." else f"{parent.as_posix()}/")
            partial = expanded.name if raw else ""

        try:
            entries = sorted(base_dir.iterdir(), key=lambda path: (not path.is_dir(), path.name.lower()))
        except OSError:
            return []

        matches: list[str] = []
        for entry in entries:
            name = entry.name
            if not include_hidden and name.startswith("."):
                continue
            if not name.startswith(partial):
                continue
            display = f"{prefix}{name}"
            if entry.is_dir():
                display += "/"
            matches.append(display)
        return matches

    def _resolve_path(self, path: Path) -> Path:
        if path.is_absolute():
            return path
        return (self.sandbox / path).resolve()

    @staticmethod
    def _discover_commands() -> set[str]:
        commands: set[str] = set()
        for entry in os.environ.get("PATH", "").split(os.pathsep):
            if not entry:
                continue
            path = Path(entry)
            if not path.is_dir():
                continue
            try:
                for child in path.iterdir():
                    if child.is_file() and os.access(child, os.X_OK):
                        commands.add(child.name)
            except OSError:
                continue
        for builtin in ("cd", "pwd", "echo", "export", "source", "alias", "type", "jobs", "fg", "bg"):
            commands.add(builtin)
        return commands


COMPLETER = SandboxCompleter()


class ShellSession:
    """Persistent interactive bash session for a level sandbox."""

    def __init__(self, sandbox: Path):
        self.sandbox = sandbox
        self.pid: int | None = None
        self.fd: int | None = None

    def start(self) -> None:
        if self.pid is not None:
            return

        pid, fd = pty.fork()
        if pid == 0:
            os.chdir(self.sandbox)
            env = {**os.environ, "SANDBOX": str(self.sandbox), "TERM": os.environ.get("TERM", "xterm")}
            os.execvpe("bash", ["bash", "--noprofile", "--norc", "-i"], env)

        self.pid = pid
        self.fd = fd
        attrs = termios.tcgetattr(self.fd)
        attrs[3] &= ~termios.ECHO
        termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
        self._drain_output()
        self.run(
            "export PS1='' PROMPT_COMMAND='' HISTFILE=/dev/null\n"
            "set +o history\n"
            "bind 'set enable-bracketed-paste off' >/dev/null 2>&1 || true\n"
        )

    def _read_available(self, timeout: float = 0.1) -> str:
        if self.fd is None:
            return ""

        chunks: list[bytes] = []
        while True:
            ready, _, _ = select.select([self.fd], [], [], timeout)
            if not ready:
                break
            try:
                data = os.read(self.fd, 4096)
            except OSError:
                break
            if not data:
                break
            chunks.append(data)
            timeout = 0
        return b"".join(chunks).decode("utf-8", errors="replace")

    def _drain_output(self) -> str:
        return self._read_available(timeout=0.2)

    @staticmethod
    def _clean_terminal_output(text: str) -> str:
        return BRACKETED_PASTE_RE.sub("", text)

    def run(self, cmd: str) -> int:
        if self.fd is None:
            self.start()
        assert self.fd is not None

        allowed, reason = validate_command(cmd)
        if not allowed:
            console.print(f"[red]{reason}[/red]")
            return 1

        warn_command(cmd)

        sentinel = f"__LM_DONE_{uuid.uuid4().hex}__"
        wrapped = f"{cmd}\nprintf '{sentinel}:%s\\n' $?\n"
        os.write(self.fd, wrapped.encode("utf-8"))

        output = ""
        deadline = time.time() + 300
        while sentinel not in output and time.time() < deadline:
            output += self._read_available(timeout=0.5)

        clean = output
        clean = clean.replace(wrapped, "")
        clean = re.sub(rf"\r?\n?{re.escape(sentinel)}:\d+\r?\n?", "", clean)
        clean = self._clean_terminal_output(clean)
        clean = clean.strip("\r\n")
        if clean:
            console.print(clean, end="" if clean.endswith("\n") else "\n")

        match = re.search(rf"{re.escape(sentinel)}:(\d+)", output)
        return int(match.group(1)) if match else 1

    def close(self) -> None:
        if self.fd is None:
            return
        try:
            os.write(self.fd, b"exit\n")
        except OSError:
            pass
        try:
            os.close(self.fd)
        except OSError:
            pass
        self.fd = None
        self.pid = None


# ─── Progress helpers ─────────────────────────────────────────────────────────

def load_progress() -> dict:
    if not PROGRESS_FILE.exists():
        return {
            "player_name": "",
            "total_xp": 0,
            "completed_levels": [],
            "current_module": "",
            "current_level": "",
            "module_certificates": [],
            "time_per_level": {},
            "level_start_time": None,
        }
    data = json.loads(PROGRESS_FILE.read_text(encoding="utf-8"))
    data.setdefault("time_per_level", {})
    data.setdefault("level_start_time", None)
    data.setdefault("module_certificates", [])
    return data


def save_progress(progress: dict) -> None:
    PROGRESS_FILE.write_text(json.dumps(progress, indent=2), encoding="utf-8")


# ─── Level registry ───────────────────────────────────────────────────────────

def load_levels() -> list[dict]:
    if not LEVELS_REGISTRY.exists():
        console.print("[red]levels.json not found. Run scripts/generate_levels.py first.[/red]")
        sys.exit(1)
    data = json.loads(LEVELS_REGISTRY.read_text(encoding="utf-8"))

    def sort_key(name: str) -> tuple[int, str]:
        match = re.search(r"(\d+)", name)
        return (int(match.group(1)) if match else 9999, name)

    modules = data["modules"]
    for module in modules:
        module["levels"] = sorted(module["levels"], key=lambda level: sort_key(level["name"]))
    return sorted(modules, key=lambda module: sort_key(module["name"]))


# ─── Command runner ───────────────────────────────────────────────────────────

def run_in_sandbox(cmd: str, shell_session: ShellSession) -> int:
    """Run a shell command inside the level's persistent shell session."""
    return shell_session.run(cmd)


def configure_readline(sandbox: Path) -> None:
    COMPLETER.set_sandbox(sandbox)
    readline.set_completer(COMPLETER.complete)
    readline.set_completer_delims(" \t\n`@$><=;|&{(")
    readline.parse_and_bind("tab: complete")
    readline.parse_and_bind("set show-all-if-ambiguous on")
    readline.parse_and_bind("set completion-ignore-case on")


def prompt_command() -> str:
    try:
        return input("linuxmissions> ").strip()
    except EOFError:
        raise
    except KeyboardInterrupt:
        raise


def clear_screen() -> None:
    os.system("clear")


def wait_for_enter(message: str = "Press Enter to continue") -> None:
    while True:
        try:
            show_continue_prompt(message)
            input()
            return
        except KeyboardInterrupt:
            continue
        except EOFError:
            return


def render_level_screen(progress: dict, mission: dict, level_num: int, total_levels: int, module_levels: list[dict], sandbox: Path) -> None:
    clear_screen()
    show_welcome(progress["player_name"])
    show_status(progress, mission.get("module", ""), len(module_levels))
    show_command_bar()
    console.rule(f"[bold blue]{module_title(mission.get('module', ''))}[/bold blue]")
    show_mission_briefing(mission, level_num, total_levels)
    print_safety_info()
    console.print(f"\n[dim]Sandbox:[/dim] [bold]{sandbox}[/bold]\n")


# ─── Validation ───────────────────────────────────────────────────────────────

def validate_level(level_path: Path, sandbox: Path) -> bool:
    script = level_path / "validate.sh"
    if not script.exists():
        console.print("[red]No validate.sh found for this level.[/red]")
        return False
    result = subprocess.run(
        ["bash", str(script), str(sandbox)],
        capture_output=False,
        text=True,
        env={**os.environ, "SANDBOX": str(sandbox)},
    )
    return result.returncode == 0


# ─── Elapsed time formatter ───────────────────────────────────────────────────

def fmt_elapsed(seconds: float) -> str:
    m, s = divmod(int(seconds), 60)
    return f"{m}m {s}s" if m else f"{s}s"


def current_position(modules: list[dict], progress: dict) -> tuple[int, int]:
    completed = set(progress.get("completed_levels", []))
    fallback = (0, 0)
    found_fallback = False
    for module_index, module in enumerate(modules):
        for level_index, level in enumerate(module["levels"]):
            if level["id"] not in completed:
                fallback = (module_index, level_index)
                found_fallback = True
                break
        if found_fallback:
            break

    current_module = progress.get("current_module")
    current_level = progress.get("current_level")
    for module_index, module in enumerate(modules):
        if module["name"] != current_module:
            continue
        for level_index, level in enumerate(module["levels"]):
            if level["name"] == current_level:
                if level["id"] in completed:
                    return fallback
                if (module_index, level_index) != fallback:
                    return fallback
                return module_index, level_index

    return fallback


def advance(modules: list[dict], module_index: int, level_index: int) -> tuple[int | None, int | None]:
    if level_index + 1 < len(modules[module_index]["levels"]):
        return module_index, level_index + 1
    if module_index + 1 < len(modules):
        return module_index + 1, 0
    return None, None


def ensure_current_level(progress: dict, modules: list[dict]) -> None:
    if not modules:
        console.print("[red]No modules found in levels.json.[/red]")
        sys.exit(1)

    module_index, level_index = current_position(modules, progress)
    progress["current_module"] = modules[module_index]["name"]
    progress["current_level"] = modules[module_index]["levels"][level_index]["name"]
    save_progress(progress)


# ─── Level loop ───────────────────────────────────────────────────────────────

def play_level(
    level: dict,
    level_num: int,
    total_levels: int,
    progress: dict,
    module_levels: list[dict],
) -> bool:
    """Play a single level. Return True if completed (or skipped)."""
    mission = level["mission"]
    level_id = level["id"]
    level_path = REPO_ROOT / level["path"]
    sandbox = prepare_level(level_path, level_id)
    shell_session = ShellSession(sandbox)
    shell_session.start()
    configure_readline(sandbox)
    render_level_screen(progress, mission, level_num, total_levels, module_levels, sandbox)

    hint_index = 0
    hints = [level_path / f"hint-{i}.txt" for i in range(1, 4)]

    progress["level_start_time"] = time.time()
    save_progress(progress)

    while True:
        try:
            raw = prompt_command()
        except (EOFError, KeyboardInterrupt):
            console.print("\n[dim]Use 'quit' to exit.[/dim]")
            continue

        if not raw:
            continue

        cmd_lower = raw.lower()

        # ── Meta-commands ──────────────────────────────────────────────────
        if cmd_lower in ("quit", "exit", "q"):
            console.print("[dim]Progress saved. See you next time![/dim]")
            shell_session.close()
            save_progress(progress)
            sys.exit(0)

        if cmd_lower == "help":
            show_help()
            continue

        if cmd_lower == "status":
            show_status(progress, mission.get("module", ""), len(module_levels))
            continue

        if cmd_lower == "objective":
            render_level_screen(progress, mission, level_num, total_levels, module_levels, sandbox)
            continue

        if cmd_lower == "hint":
            available = [h for h in hints if h.exists()]
            if hint_index < len(available):
                show_guidance(available[hint_index].read_text(encoding="utf-8"), hint_index + 1)
                hint_index += 1
            else:
                console.print("[dim]No more hints for this level.[/dim]")
            continue

        if cmd_lower == "reset":
            console.print("[yellow]Resetting sandbox…[/yellow]")
            shell_session.close()
            sandbox = prepare_level(level_path, level_id)
            shell_session = ShellSession(sandbox)
            shell_session.start()
            configure_readline(sandbox)
            render_level_screen(progress, mission, level_num, total_levels, module_levels, sandbox)
            hint_index = 0
            continue

        if cmd_lower == "skip":
            console.print("[yellow]Level skipped (no XP awarded).[/yellow]")
            shell_session.close()
            return True

        if cmd_lower == "validate":
            # Explicit validation trigger
            pass
        else:
            # Run the shell command in sandbox
            run_in_sandbox(raw, shell_session)

        # ── Auto-validate after every command ─────────────────────────────
        if validate_level(level_path, sandbox):
            elapsed = fmt_elapsed(time.time() - (progress.get("level_start_time") or time.time()))
            xp = mission.get("xp", 100)
            progress["total_xp"] = progress.get("total_xp", 0) + xp
            progress["completed_levels"] = list(
                set(progress.get("completed_levels", []) + [level_id])
            )
            progress["time_per_level"][level_id] = elapsed
            progress["level_start_time"] = None
            save_progress(progress)

            debrief = level_path / "debrief.md"
            shell_session.close()
            clear_screen()
            show_post_level_debrief(debrief, xp, elapsed)
            wait_for_enter()
            return True

    return True


# ─── Module loop ──────────────────────────────────────────────────────────────

def play_module(module: dict, progress: dict) -> None:
    levels = module["levels"]
    module_name = module["name"]
    completed = set(progress.get("completed_levels", []))

    # Find the first incomplete level
    start_index = 0
    for i, lv in enumerate(levels):
        if lv["id"] not in completed:
            start_index = i
            break
    else:
        console.print(f"[green]Module '{module_title(module_name)}' already complete![/green]")
        return

    module_xp_before = progress.get("total_xp", 0)

    for i, level in enumerate(levels[start_index:], start=start_index + 1):
        if level["id"] in completed:
            console.print(f"[dim]Skipping completed level: {level['name']}[/dim]")
            continue
        play_level(level, i, len(levels), progress, levels)

    # Module complete?
    completed_now = set(progress.get("completed_levels", []))
    module_ids = {lv["id"] for lv in levels}
    if module_ids.issubset(completed_now):
        module_xp = progress.get("total_xp", 0) - module_xp_before
        show_module_completion(module_name, module_xp)
        cert = save_certificate(progress["player_name"], module_name, module_xp)
        if module_name not in progress.get("module_certificates", []):
            progress.setdefault("module_certificates", []).append(module_name)
        save_progress(progress)


def maybe_complete_module(module: dict, progress: dict) -> None:
    module_name = module["name"]
    levels = module["levels"]
    completed_now = set(progress.get("completed_levels", []))
    module_ids = {lv["id"] for lv in levels}

    if not module_ids.issubset(completed_now):
        return
    if module_name in progress.get("module_certificates", []):
        return

    module_xp = sum(
        lv["mission"].get("xp", 100)
        for lv in levels
        if lv["id"] in completed_now
    )
    show_module_completion(module_name, module_xp)
    save_certificate(progress["player_name"], module_name, module_xp)
    progress.setdefault("module_certificates", []).append(module_name)
    save_progress(progress)


# ─── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    clear_screen()

    progress = load_progress()
    modules = load_levels()

    # Player name
    progress["player_name"] = prompt_player_name(progress.get("player_name", ""))
    save_progress(progress)

    show_welcome(progress["player_name"])
    all_ids = {lv["id"] for mod in modules for lv in mod["levels"]}
    if all_ids.issubset(set(progress.get("completed_levels", []))):
        show_victory(progress)
        return

    ensure_current_level(progress, modules)

    while True:
        modules = load_levels()
        progress = load_progress()
        module_index, level_index = current_position(modules, progress)
        current_module = modules[module_index]
        current_level = current_module["levels"][level_index]

        progress["current_module"] = current_module["name"]
        progress["current_level"] = current_level["name"]
        save_progress(progress)

        play_level(
            current_level,
            level_index + 1,
            len(current_module["levels"]),
            progress,
            current_module["levels"],
        )

        progress = load_progress()
        maybe_complete_module(current_module, progress)

        next_module_index, next_level_index = advance(modules, module_index, level_index)
        if next_module_index is None:
            show_victory(progress)
            return

        progress["current_module"] = modules[next_module_index]["name"]
        progress["current_level"] = modules[next_module_index]["levels"][next_level_index]["name"]
        save_progress(progress)


if __name__ == "__main__":
    main()
