"""Player name prompt."""
from __future__ import annotations

from rich.prompt import Prompt
from .ui import console


def prompt_player_name(existing: str = "") -> str:
    if existing:
        return existing

    console.print("[bold cyan]What's your name, traveler?[/bold cyan]")
    name = Prompt.ask("[cyan]Name[/cyan]").strip() or "Hacker"
    return name
