"""Module completion certificates for LinuxMissions."""
from __future__ import annotations

from datetime import datetime
from pathlib import Path

from .ui import console

CERT_DIR = Path(__file__).resolve().parent.parent / "completion"


def generate_certificate(player_name: str, module_name: str, xp: int) -> str:
    title = module_name.replace("-", " ").title()
    date = datetime.now().strftime("%Y-%m-%d")
    return f"""
╔══════════════════════════════════════════════════════╗
║          L I N U X M I S S I O N S                  ║
║            Certificate of Completion                 ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║  This certifies that                                 ║
║                                                      ║
║    {player_name:<48}  ║
║                                                      ║
║  has completed                                       ║
║                                                      ║
║    {title:<48}  ║
║                                                      ║
║  XP Earned: {xp:<41}  ║
║  Date:      {date:<41}  ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
"""


def save_certificate(player_name: str, module_name: str, xp: int) -> Path:
    CERT_DIR.mkdir(parents=True, exist_ok=True)
    cert_text = generate_certificate(player_name, module_name, xp)
    slug = module_name.replace("/", "-")
    path = CERT_DIR / f"certificate-{slug}.txt"
    path.write_text(cert_text, encoding="utf-8")
    console.print(f"[dim]Certificate saved → {path}[/dim]")
    return path
