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
import shutil
import signal
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
    from engine.runner import kill_sandbox_processes, run_validate
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
    from runner import kill_sandbox_processes, run_validate
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
META_COMMANDS = ("help", "hint", "hints", "status", "objective", "reset", "skip", "quit", "exit", "validate", "edit")
COMMAND_TIMEOUT = 300
HEREDOC_RE = re.compile(r"(?<!<)<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")

# Full-screen / interactive programs that need the real terminal.
INTERACTIVE_PROGRAMS = {
    "edit", "nano", "pico", "vi", "vim", "nvim", "view", "emacs", "micro", "mcedit",
    "less", "more", "most", "man", "info", "top", "htop", "btop", "watch",
    "visudo", "vipw", "vigr", "tmux", "screen", "mc", "ncdu", "nmtui",
}
# Programs that start an interactive prompt only when given no arguments.
REPL_PROGRAMS = {"python", "python3", "bash", "sh", "zsh", "sqlite3", "bc", "node", "irb"}

# Hint i (1-based) multiplies the level's XP by HINT_XP_FACTOR[i] once revealed.
HINT_XP_FACTOR = {0: 1.0, 1: 0.9, 2: 0.75, 3: 0.5}


def xp_percent(hints_revealed: int) -> int:
    return int(HINT_XP_FACTOR.get(hints_revealed, 0.5) * 100)


def default_editor() -> str:
    for name in ("nano", "vim", "vi"):
        if shutil.which(name):
            return name
    return "vi"


def is_interactive_command(cmd: str) -> bool:
    """True for a plain call to a full-screen program, e.g. `nano notes.txt` or `crontab -e`."""
    if re.search(r"[|;&<>`]|\$\(", cmd):
        return False
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return False
    while tokens and tokens[0] in ("sudo", "command"):
        tokens = tokens[1:]
    if not tokens:
        return False
    prog = tokens[0].rsplit("/", 1)[-1]
    if prog in INTERACTIVE_PROGRAMS:
        return True
    if prog in REPL_PROGRAMS and len(tokens) == 1:
        return True
    if prog == "crontab" and "-e" in tokens:
        return True
    if prog == "systemctl" and "edit" in tokens:
        return True
    return False


def _mask_quoted(line: str) -> str:
    """Replace text inside quotes with spaces, keeping a heredoc's own quoted delimiter (<<'EOF')."""
    out = []
    quote = ""
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == quote:
                quote = ""
                out.append(ch)
            elif ch == "\\" and quote == '"' and i + 1 < len(line):
                out.append("  ")
                i += 1
            else:
                out.append(" ")
        elif ch == "\\" and i + 1 < len(line):
            out.append("  ")
            i += 1
        elif ch in ("'", '"'):
            # A quoted heredoc delimiter stays visible: <<'EOF', << "EOF", <<-'EOF'
            if re.search(r"<<-?\s*$", "".join(out)):
                end = line.find(ch, i + 1)
                if end != -1:
                    out.append(line[i:end + 1])
                    i = end + 1
                    continue
            quote = ch
            out.append(ch)
        elif ch == "#" and (not out or out[-1] in " \t;|&("):
            break  # comment
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def needs_more_input(text: str) -> bool:
    """True when `text` is an unfinished shell command (open heredoc, quote, if/for, trailing | or \\)."""
    if text.rstrip().endswith("\\") and not text.rstrip().endswith("\\\\"):
        return True
    # Open heredocs: checked by hand because old bash (macOS 3.2) does not report them.
    lines = text.split("\n")
    pending: list[tuple[str, bool]] = []
    for line in lines:
        if pending:
            delim, strip_tabs = pending[0]
            if (line.lstrip("\t") if strip_tabs else line) == delim:
                pending.pop(0)
            continue
        for m in HEREDOC_RE.finditer(_mask_quoted(line)):
            pending.append((m.group(3), m.group(1) == "-"))
    if pending:
        return True
    result = subprocess.run(["bash", "-n"], input=text + "\n", capture_output=True, text=True)
    err = result.stderr
    return any(msg in err for msg in ("unexpected end of file", "unexpected EOF", "delimited by end-of-file"))


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
            # Python ignores SIGPIPE; restore the default so `cmd | head` behaves like a normal shell.
            signal.signal(signal.SIGPIPE, signal.SIG_DFL)
            os.chdir(self.sandbox)
            # $SANDBOX/bin comes first so a level's tools (and shared mocks such as
            # crontab or apt) win over the host's real ones.
            path = f"{self.sandbox}/bin{os.pathsep}{os.environ.get('PATH', '/usr/bin:/bin')}"
            env = {**os.environ, "SANDBOX": str(self.sandbox), "PATH": path,
                   "TERM": os.environ.get("TERM", "xterm")}
            os.execvpe("bash", ["bash", "--noprofile", "--norc", "-i"], env)

        self.pid = pid
        self.fd = fd
        attrs = termios.tcgetattr(self.fd)
        attrs[3] &= ~termios.ECHO
        termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
        self._drain_output()
        self.capture(
            "export PS1='' PS2='' PROMPT_COMMAND='' HISTFILE=/dev/null\n"
            "set +o history\n"
            "bind 'set enable-bracketed-paste off' >/dev/null 2>&1 || true"
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

    def alive(self) -> bool:
        if self.pid is None:
            return False
        try:
            pid, _ = os.waitpid(self.pid, os.WNOHANG)
        except ChildProcessError:
            return False
        return pid == 0

    def _wait_for(self, sentinel: str, deadline: float) -> str:
        output = ""
        while sentinel not in output and time.time() < deadline:
            output += self._read_available(timeout=0.5)
            if sentinel not in output and not self.alive():
                output += self._read_available(timeout=0.1)
                break
        return output

    def _restart(self) -> None:
        """The player's shell exited (e.g. `exit`): start a fresh one in the sandbox."""
        try:
            if self.fd is not None:
                os.close(self.fd)
        except OSError:
            pass
        self.fd = None
        self.pid = None
        self.start()

    def _execute(self, cmd: str) -> tuple[int, str]:
        """Send cmd to the shell, wait for it to finish, return (exit code, output).

        Ctrl-C while waiting interrupts the running command (not the game).
        """
        if self.fd is None:
            self.start()
        assert self.fd is not None

        sentinel = f"__LM_DONE_{uuid.uuid4().hex}__"
        os.write(self.fd, f"{cmd}\nprintf '{sentinel}:%s\\n' $?\n".encode("utf-8"))

        output = ""
        deadline = time.time() + COMMAND_TIMEOUT
        try:
            output = self._wait_for(sentinel, deadline)
        except KeyboardInterrupt:
            # SIGINT to the foreground job; the tty may flush the queued sentinel
            # line, so send a fresh one and wait for that instead.
            os.write(self.fd, b"\x03")
            time.sleep(0.2)
            sentinel = f"__LM_DONE_{uuid.uuid4().hex}__"
            os.write(self.fd, f"printf '{sentinel}:%s\\n' 130\n".encode("utf-8"))
            output += self._wait_for(sentinel, time.time() + 10)

        match = re.search(rf"{re.escape(sentinel)}:(\d+)", output)
        code = int(match.group(1)) if match else 1
        clean = re.sub(r"\r?\n?__LM_DONE_[0-9a-f]{32}__:\d+\r?\n?", "", output)
        clean = self._clean_terminal_output(clean).replace("\r\n", "\n").strip("\r\n")
        if not match:
            if not self.alive():
                self._restart()
                clean += ("\n[the shell exited — started a fresh shell in the sandbox; "
                          "variables, aliases and the current directory were reset]")
            else:
                clean += f"\n[command still running after {COMMAND_TIMEOUT}s — press Ctrl-C next time to stop it]"
        return code, clean

    def capture(self, cmd: str) -> str:
        """Run a helper command silently and return its output."""
        return self._execute(cmd)[1]

    def cwd(self) -> Path:
        out = self.capture("pwd").strip().splitlines()
        path = Path(out[-1]) if out else self.sandbox
        return path if path.is_dir() else self.sandbox

    def run(self, cmd: str) -> int:
        allowed, reason = validate_command(cmd)
        if not allowed:
            console.print(f"[red]{reason}[/red]")
            return 1

        warn_command(cmd)

        if is_interactive_command(cmd):
            return self.run_in_terminal(cmd)

        code, clean = self._execute(cmd)
        if clean:
            console.print(clean, end="" if clean.endswith("\n") else "\n", markup=False, highlight=False)
        return code

    def run_in_terminal(self, cmd: str) -> int:
        """Run a full-screen program (editor, pager, man, top) on the real terminal.

        The persistent shell talks through a pipe-like pty that full-screen
        programs cannot use, so they run here instead, in the shell's current
        directory and with its exported variables.
        """
        cwd = self.cwd()
        env_dump = self.capture("env")
        env = dict(os.environ)
        for line in env_dump.splitlines():
            key, sep, value = line.partition("=")
            if sep and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                env[key] = value
        env["SANDBOX"] = str(self.sandbox)
        tokens = cmd.split(None, 1)
        if tokens[0] == "edit":
            editor = os.environ.get("VISUAL") or os.environ.get("EDITOR") or default_editor()
            cmd = f"{editor} {tokens[1] if len(tokens) > 1 else ''}"
        try:
            return subprocess.call(["bash", "-c", cmd], cwd=str(cwd), env=env)
        except KeyboardInterrupt:
            return 130

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
    """Read one command. Unfinished input (heredoc, if/for, open quote, trailing |) continues on `...> ` lines."""
    first = input("linuxmissions> ")
    if not first.strip():
        return ""
    if first.strip().lower() in META_COMMANDS or first.strip().split()[0].lower() in ("edit",):
        return first.strip()
    lines = [first]
    if not needs_more_input(first):
        return first.strip()
    # Inside a heredoc or block, Tab inserts a tab (needed for <<-) instead of completing.
    readline.parse_and_bind("tab: tab-insert")
    try:
        while needs_more_input("\n".join(lines)):
            try:
                lines.append(input("...> "))
            except KeyboardInterrupt:
                console.print("\n[dim]Input cancelled.[/dim]")
                return ""
            except EOFError:
                break
    finally:
        readline.parse_and_bind("tab: complete")
    return "\n".join(lines).strip()


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

def validate_level(level_path: Path, sandbox: Path, verbose: bool = False) -> bool:
    """Run validate.sh. Auto-validation after each command is silent; `validate` shows why."""
    ok, message = run_validate(level_path, sandbox)
    if verbose and message:
        console.print(message, markup=False, highlight=False)
    return ok


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

    hints = [h for h in (level_path / f"hint-{i}.txt" for i in range(1, 4)) if h.exists()]
    hints_used = progress.setdefault("hints_used", {})

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
            used = hints_used.get(level_id, 0)
            if used >= len(hints):
                console.print("[dim]No more hints for this level. Type [bold]hints[/bold] to see them again.[/dim]")
                continue
            nxt = used + 1
            if nxt == len(hints) and nxt >= 3:
                console.print(
                    f"[yellow]Hint {nxt} shows most of the solution. "
                    f"Your XP for this level drops to {int(HINT_XP_FACTOR[nxt] * 100)}%.[/yellow]"
                )
                try:
                    answer = input("Show it? [y/N] ").strip().lower()
                except (EOFError, KeyboardInterrupt):
                    answer = ""
                if answer not in ("y", "yes"):
                    continue
            hints_used[level_id] = nxt
            save_progress(progress)
            show_guidance(hints[nxt - 1].read_text(encoding="utf-8"), nxt, xp_percent(nxt))
            continue

        if cmd_lower == "hints":
            used = hints_used.get(level_id, 0)
            if not used:
                console.print("[dim]No hints revealed yet. Type [bold]hint[/bold] for the first one.[/dim]")
            for n in range(1, used + 1):
                show_guidance(hints[n - 1].read_text(encoding="utf-8"), n, xp_percent(n))
            continue

        if cmd_lower == "reset":
            console.print("[yellow]Resetting sandbox…[/yellow]")
            shell_session.close()
            sandbox = prepare_level(level_path, level_id)
            shell_session = ShellSession(sandbox)
            shell_session.start()
            configure_readline(sandbox)
            render_level_screen(progress, mission, level_num, total_levels, module_levels, sandbox)
            continue

        if cmd_lower == "skip":
            console.print("[yellow]Level skipped (no XP awarded).[/yellow]")
            shell_session.close()
            kill_sandbox_processes(sandbox)
            return True

        explicit = cmd_lower == "validate"
        if not explicit:
            run_in_sandbox(raw, shell_session)

        # ── Auto-validate after every command (silent unless asked) ────────
        if validate_level(level_path, sandbox, verbose=explicit):
            elapsed = fmt_elapsed(time.time() - (progress.get("level_start_time") or time.time()))
            xp = int(mission.get("xp", 100) * HINT_XP_FACTOR.get(hints_used.get(level_id, 0), 0.5))
            progress["total_xp"] = progress.get("total_xp", 0) + xp
            progress["completed_levels"] = list(
                set(progress.get("completed_levels", []) + [level_id])
            )
            progress["time_per_level"][level_id] = elapsed
            progress["level_start_time"] = None
            save_progress(progress)

            debrief = level_path / "debrief.md"
            shell_session.close()
            kill_sandbox_processes(sandbox)
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
