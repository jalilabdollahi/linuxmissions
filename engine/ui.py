"""LinuxMissions UI helpers using Rich."""
from __future__ import annotations

from pathlib import Path

from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich import box

console = Console()

BANNER = r"""
 _     _                        __  __ _         _
| |   (_)_ __  _   ___  __    |  \/  (_)___ ___(_) ___  _ __  ___
| |   | | '_ \| | | \ \/ /    | |\/| | / __/ __| |/ _ \| '_ \/ __|
| |___| | | | | |_| |>  <     | |  | | \__ \__ \ | (_) | | | \__ \
|_____|_|_| |_|\__,_/_/\_\    |_|  |_|_|___/___/_|\___/|_| |_|___/
"""


def module_title(name: str) -> str:
    return name.replace("-", " ").title()


def show_welcome(player_name: str) -> None:
    console.print(f"[bold cyan]{BANNER}[/bold cyan]")
    console.print(
        Panel(
            f"[bold]Welcome, [green]{player_name}[/green]![/bold]\n\n"
            "Master Linux one mission at a time.\n"
            "Each level drops you into a broken or incomplete scenario — "
            "fix it using real shell commands.\n\n"
            "[dim]Tab completes commands and file names. Type [bold]hint[/bold] for help, "
            "[bold]status[/bold] for progress, or [bold]skip[/bold] to move on.[/dim]",
            title="[bold bright_cyan]MISSION CONTROL[/bold bright_cyan]",
            border_style="bright_cyan",
            box=box.ROUNDED,
        )
    )


def show_mission_briefing(mission: dict, level_num: int, total_levels: int) -> None:
    diff_color = {"beginner": "green", "intermediate": "yellow", "advanced": "red"}.get(
        mission.get("difficulty", "beginner"), "white"
    )
    concepts = ", ".join(mission.get("concepts", []))
    console.print(
        Panel(
            f"[bold white]{mission['description']}[/bold white]\n\n"
            f"[bold yellow]Objective:[/bold yellow] {mission['objective']}\n\n"
            f"[dim]Concepts: {concepts}[/dim]",
            title=f"[bold bright_cyan]MISSION {level_num}/{total_levels}: {mission['name']}[/bold bright_cyan]  "
                  f"[{diff_color}]{mission.get('difficulty','').upper()}[/{diff_color}]  "
                  f"[bright_magenta]+{mission.get('xp', 100)} XP[/bright_magenta]  "
                  f"[dim]~{mission.get('expected_time','?')}[/dim]",
            border_style="bright_cyan",
            box=box.ROUNDED,
        )
    )


def show_status(progress: dict, module_name: str, total_module_levels: int) -> None:
    completed = len(
        [l for l in progress.get("completed_levels", []) if l.startswith(module_name)]
    )
    overall_completed = len(progress.get("completed_levels", []))
    table = Table(box=box.SIMPLE, show_header=False)
    table.add_row("[dim]Player[/dim]", f"[bold]{progress.get('player_name', '?')}[/bold]")
    table.add_row("[dim]Total XP[/dim]", f"[bold yellow]{progress.get('total_xp', 0)}[/bold yellow]")
    table.add_row(
        "[dim]Module Progress[/dim]",
        f"{completed}/{total_module_levels} levels",
    )
    table.add_row("[dim]Completed Missions[/dim]", f"{overall_completed}")
    console.print(Panel(table, title="[bold bright_cyan]Progress[/bold bright_cyan]", border_style="bright_cyan", box=box.ROUNDED))


def show_guidance(hint_text: str, hint_num: int) -> None:
    console.print(
        Panel(
            f"[yellow]{hint_text.strip()}[/yellow]",
            title=f"[bold yellow]Hint {hint_num}[/bold yellow]",
            border_style="yellow",
        )
    )


def show_help() -> None:
    table = Table(box=box.SIMPLE_HEAVY, show_header=True, header_style="bold bright_cyan")
    table.add_column("Command")
    table.add_column("Description")
    rows = [
        ("Tab", "Autocomplete commands and sandbox file names"),
        ("hint", "Get the next hint (up to 3)"),
        ("status", "Show your XP and module progress"),
        ("objective", "Re-display the mission objective"),
        ("reset", "Tear down and rebuild this level's sandbox"),
        ("skip", "Skip this level (no XP awarded)"),
        ("quit / exit", "Save progress and exit"),
        ("help", "Show this help"),
        ("<any shell cmd>", "Run a command in the level sandbox"),
    ]
    for cmd, desc in rows:
        table.add_row(f"[bold]{cmd}[/bold]", desc)
    console.print(Panel(table, title="[bold bright_cyan]Command Palette[/bold bright_cyan]", border_style="bright_cyan", box=box.ROUNDED))


def show_command_bar() -> None:
    table = Table(box=box.SIMPLE, show_header=False, expand=True, padding=(0, 1))
    table.add_column("Action", style="bold bright_cyan")
    table.add_column("What It Does", style="white")
    rows = [
        ("hint", "Show the next hint"),
        ("help", "Show full command list"),
        ("status", "Show progress details"),
        ("objective", "Repeat the mission objective"),
        ("reset", "Rebuild this sandbox"),
        ("skip", "Skip this mission"),
        ("quit", "Save and exit"),
        ("Tab", "Autocomplete files and commands"),
    ]
    for cmd, desc in rows:
        table.add_row(cmd, desc)
    console.print(
        Panel(
            table,
            title="[bold bright_cyan]Available Actions[/bold bright_cyan]",
            border_style="bright_cyan",
            box=box.ROUNDED,
        )
    )


def show_post_level_debrief(debrief_path: Path, xp_earned: int, elapsed: str) -> None:
    text = debrief_path.read_text(encoding="utf-8") if debrief_path.exists() else ""
    console.print(
        Panel(
            Markdown(text) if text else "[dim]No debrief available.[/dim]",
            title=f"[bold green]Level Complete! +{xp_earned} XP  [dim]{elapsed}[/dim][/bold green]",
            border_style="green",
        )
    )


def show_continue_prompt(message: str = "Press Enter to continue") -> None:
    console.print(
        Panel(
            f"[bold bright_cyan]{message}[/bold bright_cyan]",
            border_style="bright_cyan",
            box=box.ROUNDED,
        )
    )


def show_victory(progress: dict) -> None:
    console.print(
        Panel(
            f"[bold yellow]You've completed all missions![/bold yellow]\n\n"
            f"Total XP: [bold cyan]{progress.get('total_xp', 0)}[/bold cyan]\n\n"
            "[dim]The terminal is your canvas. Keep exploring.[/dim]",
            title="[bold]LinuxMissions Complete[/bold]",
            border_style="yellow",
        )
    )


def show_module_completion(module_name: str, xp: int) -> None:
    console.print(
        Panel(
            f"[bold green]Module '{module_title(module_name)}' finished![/bold green]\n"
            f"Module XP: [bold yellow]{xp}[/bold yellow]",
            border_style="green",
        )
    )


def render_markdown(text: str) -> None:
    console.print(Markdown(text))
