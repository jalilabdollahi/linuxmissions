"""LinuxMissions UI helpers using Rich.

Every colour is a hex value from the xterm 256-colour palette, so the screens
look the same in truecolor terminals (iTerm) and 256-colour ones (Terminal.app,
the Docker container's TERM=xterm-256color).
"""
from __future__ import annotations

import re
from pathlib import Path

from rich import box
from rich.console import Console, Group
from rich.markdown import Markdown
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.theme import Theme

# ─── Palette ──────────────────────────────────────────────────────────────────
ACCENT = "#5fd7ff"   # cyan: frames, keys, module progress
GOLD = "#ffd75f"     # XP, objective, hints
GOLD_DIM = "#af8700"
GREEN = "#5fd75f"    # success
VIOLET = "#d787ff"   # overall progress
RED_BG = "#af005f"
RED_FG = "#ff87af"
TEXT = "#d0d0d0"
MUTED = "#a8a8a8"
TRACK = "#3a3a3a"    # empty part of a bar, quiet frames
CHIP = "#303030"
FRAME = "#585858"

DIFFICULTY_COLORS = {"beginner": GREEN, "intermediate": GOLD, "advanced": "#ff875f", "expert": VIOLET}

THEME = Theme({
    "markdown.h1": f"bold {ACCENT}",
    "markdown.h1.border": ACCENT,
    "markdown.h2": f"bold {ACCENT}",
    "markdown.h3": f"bold {TEXT}",
    "markdown.code": f"{'#ffd787'} on {CHIP}",
    "markdown.item.bullet": f"bold {ACCENT}",
    "markdown.link": ACCENT,
})

console = Console(theme=THEME)

BANNER = r"""
 _     _                        __  __ _         _
| |   (_)_ __  _   ___  __    |  \/  (_)___ ___(_) ___  _ __  ___
| |   | | '_ \| | | \ \/ /    | |\/| | / __/ __| |/ _ \| '_ \/ __|
| |___| | | | | |_| |>  <     | |  | | \__ \__ \ | (_) | | | \__ \
|_____|_|_| |_|\__,_/_/\_\    |_|  |_|_|___/___/_|\___/|_| |_|___/
"""
BANNER_COLORS = ["#5fd7ff", "#5fafff", "#8787ff", "#af87ff", "#d787ff"]

MODULE_TITLES = {
    1: "Filesystem", 2: "Text Processing", 3: "Permissions", 4: "Processes", 5: "Scripting",
    6: "Networking", 7: "Sysadmin", 8: "Advanced Text", 9: "Shell Environment",
    10: "Archives & Compression", 11: "Find & Pipelines", 12: "Users & Groups",
    13: "Services & Logs", 14: "Storage & Backups", 15: "Scheduling & Jobs",
    16: "Security Auditing", 17: "Monitoring & Performance", 18: "Configuration Editing",
    19: "Network Troubleshooting", 20: "Package & Release Ops", 21: "Shell Automation",
    22: "Data Processing", 23: "Boot & Recovery", 24: "System Inspection",
    25: "Linux Toolbelt", 26: "Linux War Games",
}

# (minimum total XP, rank name)
RANKS = [(0, "Recruit"), (1000, "Operator"), (5000, "Sysadmin"), (15000, "Engineer"), (30000, "Root")]

KEYS = [("hint", "−XP"), ("validate", ""), ("edit FILE", ""), ("objective", ""), ("help", ""), ("quit", "")]


# ─── Small building blocks ────────────────────────────────────────────────────

def module_number(name: str) -> int:
    match = re.match(r"module-(\d+)", name or "")
    return int(match.group(1)) if match else 0


def module_title(name: str) -> str:
    """'module-10-archives-compression' -> 'Archives & Compression'."""
    num = module_number(name)
    if num in MODULE_TITLES:
        return MODULE_TITLES[num]
    words = re.sub(r"^module-\d+-", "", name or "").replace("-", " ")
    return words.title()


def rank_for(xp: int) -> tuple[str, int, int | None, str | None]:
    """Return (rank, its threshold, next threshold, next rank)."""
    current = RANKS[0]
    following: tuple[int, str] | None = None
    for i, entry in enumerate(RANKS):
        if xp >= entry[0]:
            current = entry
            following = RANKS[i + 1] if i + 1 < len(RANKS) else None
    return current[1], current[0], (following[0] if following else None), (following[1] if following else None)


def progress_bar(done: int, total: int, width: int, color: str) -> Text:
    filled = max(0, min(width, round(width * done / total))) if total else 0
    bar = Text("━" * filled, style=color)
    bar.append("━" * (width - filled), style=TRACK)
    return bar


def pill(label: str, bg: str, fg: str = "black") -> Text:
    # Style the span, not the Text: a Text's base style would also paint the
    # padding of a table cell or a justified line.
    text = Text()
    text.append(f" {label} ", style=f"bold {fg} on {bg}")
    return text


def _counter(text: str) -> Text:
    return Text(f"  {text:>7}", style="white")


# ─── Screens ──────────────────────────────────────────────────────────────────

def show_welcome(player_name: str, progress: dict | None = None, total_levels: int = 0) -> None:
    """Shown once when the game starts."""
    banner = Text()
    for line, color in zip(BANNER.strip("\n").splitlines(), BANNER_COLORS):
        banner.append(line + "\n", style=f"bold {color}")
    console.print(banner)

    progress = progress or {}
    xp = progress.get("total_xp", 0)
    done = len(progress.get("completed_levels", []))
    rank, _, _, _ = rank_for(xp)
    greeting = Text()
    greeting.append("Welcome back, " if done else "Welcome, ", style=TEXT)
    greeting.append(player_name, style=f"bold {ACCENT}")
    greeting.append(".", style=TEXT)
    lines = [greeting]
    if done:
        stats = Text()
        stats.append(f"{xp:,} XP", style=f"bold {GOLD}")
        stats.append("  ·  ", style="dim")
        stats.append(rank, style=f"bold {ACCENT}")
        stats.append("  ·  ", style="dim")
        stats.append(f"{done} of {total_levels} missions done" if total_levels else f"{done} missions done",
                     style=TEXT)
        lines.append(stats)
    lines.append(Text(""))
    lines.append(Text("Each mission drops you into a broken or unfinished Linux system. "
                      "Fix it with real shell commands.", style=TEXT))
    tip = Text()
    tip.append("Tab completes commands and file names. Type ", style="dim")
    tip.append("help", style=f"bold {ACCENT}")
    tip.append(" for every command.", style="dim")
    lines.append(tip)
    console.print(Panel(Group(*lines), box=box.ROUNDED, border_style=TRACK, padding=(1, 2)))


def show_header(progress: dict, module_name: str, level_num: int, module_total: int,
                overall_done: int, overall_total: int) -> None:
    xp = progress.get("total_xp", 0)
    rank, _, _, _ = rank_for(xp)

    grid = Table.grid(expand=True)
    grid.add_column(ratio=1)
    grid.add_column(justify="right")

    title = Text()
    title.append("▍", style=ACCENT)
    title.append("LINUX", style=f"bold {ACCENT}")
    title.append("MISSIONS", style="bold white")
    who = Text()
    who.append(progress.get("player_name", "") or "player", style="bold white")
    who.append("  ·  ", style="dim")
    who.append(f"{xp:,} XP", style=f"bold {GOLD}")
    who.append("  ·  ", style="dim")
    who.append(rank, style=f"bold {ACCENT}")
    grid.add_row(title, who)
    grid.add_row(Text(""), Text(""))

    num = module_number(module_name)
    mod = Text()
    mod.append(f"MODULE {num:>2}  " if num else "MODULE     ", style="dim")
    mod.append(module_title(module_name), style=f"bold {TEXT}")
    mod_bar = progress_bar(level_num - 1, module_total, 24, ACCENT)
    mod_bar.append_text(_counter(f"{level_num}/{module_total}"))
    grid.add_row(mod, mod_bar)

    if overall_total:
        overall = Text()
        overall.append("OVERALL    ", style="dim")
        overall.append(f"{overall_done} of {overall_total} missions", style=TEXT)
        all_bar = progress_bar(overall_done, overall_total, 24, VIOLET)
        all_bar.append_text(_counter(f"{overall_done * 100 // overall_total}%"))
        grid.add_row(overall, all_bar)

    console.print(Panel(grid, box=box.ROUNDED, border_style=TRACK, padding=(0, 2)))


def show_mission_briefing(mission: dict, level_num: int, total_levels: int) -> None:
    difficulty = mission.get("difficulty", "beginner")
    badges = pill(difficulty.upper(), DIFFICULTY_COLORS.get(difficulty, TEXT))
    badges.append("  ")
    badges.append_text(pill(f"+{mission.get('xp', 100)} XP", GOLD))
    badges.append("  ")
    badges.append(f"⏱  ~{mission.get('expected_time', '?')}", style="dim")

    objective = Panel(
        Text(mission.get("objective", ""), style="white"),
        title=Text(" 🎯 OBJECTIVE ", style=f"bold {GOLD}"),
        title_align="left",
        box=box.ROUNDED,
        border_style=GOLD_DIM,
        padding=(0, 1),
    )

    parts = [badges, Text(""), Text(mission.get("description", ""), style=TEXT), Text(""), objective]
    concepts = mission.get("concepts", [])
    if concepts:
        tags = Text()
        for i, concept in enumerate(concepts):
            if i:
                tags.append("  ")
            tags.append(f" {concept} ", style=f"{TEXT} on {CHIP}")
        parts += [Text(""), tags]

    console.print(Panel(
        Group(*parts),
        title=Text.assemble((f" MISSION {level_num}/{total_levels} ", f"bold black on {ACCENT}"), " ",
                            (mission.get("name", ""), "bold white"), " "),
        title_align="left",
        box=box.ROUNDED,
        border_style=ACCENT,
        padding=(1, 2),
    ))


def show_command_bar() -> None:
    bar = Text(" ")
    for key, note in KEYS:
        bar.append(f" {key} ", style=f"bold black on {ACCENT}")
        bar.append(f" {note}  " if note else "  ", style="dim")
    console.print(bar)


def show_level_screen(progress: dict, mission: dict, level_num: int, module_total: int,
                      overall_done: int, overall_total: int, sandbox: Path) -> None:
    show_header(progress, mission.get("module", ""), level_num, module_total, overall_done, overall_total)
    show_mission_briefing(mission, level_num, module_total)
    show_command_bar()
    console.print(Text(f"  📂 {sandbox}", style="dim"))
    console.print()


def show_validation(message: str) -> None:
    """Pretty-print validate.sh output: ✅ / ❌ lines get a status pill."""
    for line in message.strip().splitlines():
        stripped = line.strip()
        if stripped.startswith("❌"):
            console.print(Text.assemble(pill("✗ NOT YET", RED_BG, "white"), "  ",
                                        (stripped[1:].strip(), RED_FG)))
        elif stripped.startswith("✅"):
            console.print(Text.assemble(pill("✔ DONE", GREEN), "  ", (stripped[1:].strip(), GREEN)))
        elif stripped:
            console.print(Text(line, style=MUTED))


def show_status(progress: dict, modules: list[dict], current_module: str = "") -> None:
    completed = set(progress.get("completed_levels", []))
    xp = progress.get("total_xp", 0)
    rank, floor, nxt, nxt_name = rank_for(xp)

    top = Text()
    top.append(progress.get("player_name", "") or "player", style="bold white")
    top.append("  ·  ", style="dim")
    top.append(f"{xp:,} XP", style=f"bold {GOLD}")
    top.append("  ·  ", style="dim")
    top.append(rank, style=f"bold {ACCENT}")
    if nxt is not None:
        rank_line = Text()
        rank_line.append("next rank  ", style="dim")
        rank_line.append_text(progress_bar(xp - floor, nxt - floor, 24, GOLD))
        rank_line.append(f"  {nxt - xp:,} XP to ", style=MUTED)
        rank_line.append(nxt_name or "", style=f"bold {ACCENT}")
    else:
        rank_line = Text("Highest rank reached.", style=MUTED)

    table = Table(box=None, show_header=False, padding=(0, 1), expand=False)
    table.add_column(justify="right", style="dim")
    table.add_column()
    table.add_column()
    table.add_column(justify="right")
    for module in modules:
        ids = [lv["id"] for lv in module["levels"]]
        done = sum(1 for i in ids if i in completed)
        total = len(ids)
        is_current = module["name"] == current_module
        color = GREEN if done == total else (ACCENT if is_current else MUTED)
        name_style = f"bold {ACCENT}" if is_current else (TEXT if done else "dim")
        marker = "▸ " if is_current else "  "
        table.add_row(str(module_number(module["name"])),
                      Text(marker + module_title(module["name"]), style=name_style),
                      progress_bar(done, total, 20, color),
                      Text(f"{done}/{total}", style="white" if done else "dim"))

    console.print(Panel(Group(top, rank_line, Text(""), table),
                        title=Text(" PROGRESS ", style=f"bold black on {ACCENT}"), title_align="left",
                        box=box.ROUNDED, border_style=TRACK, padding=(1, 2)))


def show_guidance(hint_text: str, hint_num: int, xp_percent: int | None = None, total_hints: int = 3) -> None:
    subtitle = Text(f"this level now pays {xp_percent}% XP", style="dim") if xp_percent is not None else None
    console.print(Panel(
        Text(hint_text.strip(), style="#ffd787"),
        title=Text(f" 💡 HINT {hint_num}/{total_hints} ", style=f"bold black on {GOLD}"),
        title_align="left",
        subtitle=subtitle,
        subtitle_align="right",
        box=box.ROUNDED,
        border_style=GOLD,
        padding=(1, 2),
    ))


def show_help() -> None:
    table = Table(box=None, show_header=False, padding=(0, 2))
    table.add_column(no_wrap=True)
    table.add_column(style=TEXT)
    rows = [
        ("hint", "Next hint, up to 3. Each one lowers this level's XP (90%, 75%, 50%)"),
        ("hints", "Show the hints you already revealed"),
        ("validate", "Check your work and show what is still missing"),
        ("edit FILE", "Open a file in a real editor ($EDITOR, else nano or vim)"),
        ("objective", "Show the mission again"),
        ("status", "XP, rank and progress in every module"),
        ("reset", "Rebuild this level's sandbox from scratch"),
        ("skip", "Skip this level (no XP)"),
        ("quit", "Save progress and leave"),
        ("help", "This list"),
    ]
    for key, desc in rows:
        table.add_row(pill(key, ACCENT), desc)
    table.add_row(Text(""), Text(""))
    for key, desc in [
        ("any command", "Runs for real inside the level's sandbox"),
        ("Tab", "Complete commands and file names"),
        ("multi-line", "Heredocs, if/for/while and lines ending in | or \\ continue on a ...> prompt"),
        ("Ctrl-C", "Stop a running command such as tail -f or sleep"),
    ]:
        table.add_row(Text(f" {key} ", style=f"bold {ACCENT}"), desc)
    note = Text("The sandbox lives under /tmp/linuxmissions/. Destructive host-level commands are blocked.",
                style="dim")
    console.print(Panel(Group(table, Text(""), note),
                        title=Text(" COMMANDS ", style=f"bold black on {ACCENT}"), title_align="left",
                        box=box.ROUNDED, border_style=TRACK, padding=(1, 2)))


def show_post_level_debrief(debrief_path: Path, xp_earned: int, elapsed: str, mission_name: str = "",
                            hints_used: int = 0, total_xp: int | None = None) -> None:
    stats = Table.grid(padding=(0, 3))
    stats.add_column()
    stats.add_column()
    stats.add_column()
    stats.add_row(Text(f"+{xp_earned} XP", style=f"bold {GOLD}"),
                  Text(f"⏱  {elapsed}", style="white"),
                  Text(f"💡 {hints_used} hint{'s' if hints_used != 1 else ''}", style="white"))
    parts = []
    if mission_name:
        parts += [Text(mission_name, style="bold white"), Text("")]
    parts.append(stats)
    if total_xp is not None:
        rank, floor, nxt, nxt_name = rank_for(total_xp)
        line = Text()
        line.append("Total ", style="dim")
        line.append(f"{total_xp:,} XP  ", style="bold white")
        if nxt is not None:
            line.append_text(progress_bar(total_xp - floor, nxt - floor, 30, GOLD))
            line.append(f"  {nxt - total_xp:,} XP to ", style=MUTED)
            line.append(nxt_name or "", style=f"bold {ACCENT}")
        else:
            line.append(f"Rank: {rank}", style=f"bold {ACCENT}")
        if rank_for(total_xp - xp_earned)[0] != rank:
            line.append("\n")
            line.append(f"⬆  New rank: {rank}", style=f"bold {ACCENT}")
        parts += [Text(""), line]
    console.print(Panel(Group(*parts),
                        title=Text(" ✔ MISSION COMPLETE ", style=f"bold black on {GREEN}"), title_align="left",
                        box=box.ROUNDED, border_style=GREEN, padding=(1, 2)))

    text = debrief_path.read_text(encoding="utf-8") if debrief_path.exists() else ""
    if text:
        console.print(Panel(Markdown(text), title=Text(" DEBRIEF ", style=f"bold black on {TEXT}"),
                            title_align="left", box=box.ROUNDED, border_style=FRAME, padding=(1, 2)))


def show_continue_prompt(message: str = "Press Enter to continue", next_title: str | None = None) -> None:
    line = Text("  ")
    line.append_text(pill("ENTER", ACCENT))
    if next_title:
        line.append("  next mission: ", style="dim")
        line.append(next_title, style="white")
    else:
        line.append(f"  {message}", style="dim")
    console.print(line)


def show_victory(progress: dict) -> None:
    xp = progress.get("total_xp", 0)
    body = Group(
        Text("Every mission is done.", style="bold white"),
        Text(""),
        Text.assemble(("Total ", "dim"), (f"{xp:,} XP", f"bold {GOLD}"), ("  ·  ", "dim"),
                      (rank_for(xp)[0], f"bold {ACCENT}")),
        Text(""),
        Text("The terminal is your canvas. Keep exploring.", style="dim"),
    )
    console.print(Panel(body, title=Text(" 🏆 LINUXMISSIONS COMPLETE ", style=f"bold black on {GOLD}"),
                        title_align="left", box=box.ROUNDED, border_style=GOLD, padding=(1, 2)))


def show_module_completion(module_name: str, xp: int) -> None:
    num = module_number(module_name)
    body = Group(
        Text.assemble((f"Module {num}  " if num else "", "dim"), (module_title(module_name), "bold white")),
        Text(""),
        Text.assemble(("Module XP ", "dim"), (f"{xp:,}", f"bold {GOLD}")),
    )
    console.print(Panel(body, title=Text(" ★ MODULE COMPLETE ", style=f"bold black on {GREEN}"),
                        title_align="left", box=box.ROUNDED, border_style=GREEN, padding=(1, 2)))


def render_markdown(text: str) -> None:
    console.print(Markdown(text))
