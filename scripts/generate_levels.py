#!/usr/bin/env python3
"""Walk modules/ and generate levels.json registry."""
from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MODULES_DIR = REPO / "modules"
OUTPUT = REPO / "levels.json"


def sort_key(path: Path) -> tuple[int, str]:
    match = re.search(r"(\d+)", path.name)
    return (int(match.group(1)) if match else 9999, path.name)


def main() -> None:
    modules = []
    total = 0

    for mod_dir in sorted(MODULES_DIR.iterdir(), key=sort_key):
        if not mod_dir.is_dir() or mod_dir.name.startswith("."):
            continue
        levels = []
        for lvl_dir in sorted(mod_dir.iterdir(), key=sort_key):
            if not lvl_dir.is_dir() or lvl_dir.name.startswith("."):
                continue
            mission_file = lvl_dir / "mission.yaml"
            if not mission_file.exists():
                print(f"  ⚠  Skipping {lvl_dir} — no mission.yaml")
                continue
            try:
                mission = json.loads(mission_file.read_text(encoding="utf-8"))
            except json.JSONDecodeError as e:
                print(f"  ❌ Bad JSON in {mission_file}: {e}")
                continue
            level_id = f"{mod_dir.name}/{lvl_dir.name}"
            levels.append(
                {
                    "id": level_id,
                    "name": lvl_dir.name,
                    "path": f"modules/{mod_dir.name}/{lvl_dir.name}",
                    "mission": mission,
                }
            )
            total += 1
        if levels:
            modules.append({"name": mod_dir.name, "levels": levels})
            print(f"  ✅ {mod_dir.name}: {len(levels)} levels")

    OUTPUT.write_text(
        json.dumps(
            {
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "level_count": total,
                "modules": modules,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"\n✅ levels.json written — {total} levels across {len(modules)} modules")


if __name__ == "__main__":
    main()
