#!/usr/bin/env python3
"""Find template-made or near-duplicate levels.

Flags:
  - levels that delegate to a shared generator (scripts/generated_level_runtime.py)
  - pairs of levels whose setup.sh, validate.sh or solution.sh are near-identical
    once names and numbers are blanked out (similarity >= --threshold)

Usage: scripts/check_duplicates.py [--threshold 0.85] [module filters...]
Exit code 1 if anything is flagged.
"""
from __future__ import annotations

import argparse
import difflib
import re
import sys
from itertools import combinations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FILES = ("setup.sh", "validate.sh", "solution.sh", "hint-1.txt", "hint-2.txt", "hint-3.txt")


def normalize(text: str) -> str:
    """Drop comments and blank out numbers and file names."""
    lines = [l for l in text.splitlines() if l.strip() and not l.strip().startswith("#")]
    text = "\n".join(l.strip() for l in lines)
    # Levels made from one template differ only in names and numbers.
    text = re.sub(r"\d+", "N", text)
    text = re.sub(r"[A-Za-z_][\w-]*\.(txt|log|conf|sh|csv|json|tar|gz|cfg|ini|yaml)\b", "F", text)
    return text


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("filters", nargs="*")
    ap.add_argument("--threshold", type=float, default=0.9)
    args = ap.parse_args()

    levels = sorted(p.parent for p in (REPO / "modules").glob("*/*/mission.yaml"))
    if args.filters:
        levels = [l for l in levels if any(f in f"{l.parent.name}/{l.name}" for f in args.filters)]

    flagged = 0
    for level in levels:
        for name in ("setup.sh", "validate.sh"):
            f = level / name
            if f.exists() and "generated_level_runtime" in f.read_text(encoding="utf-8", errors="replace"):
                print(f"TEMPLATE   {level.parent.name}/{level.name}: {name} uses the shared generator")
                flagged += 1
                break

    for name in FILES:
        # Hints are prose: template hints differ only by the topic word, so use a lower bar.
        limit = args.threshold - 0.1 if name.startswith("hint") else args.threshold
        docs = {}
        for level in levels:
            f = level / name
            if f.exists():
                text = f.read_text(encoding="utf-8", errors="replace")
                if "generated_level_runtime" in text or (level / "level.json").exists():
                    continue
                norm = normalize(text)
                if len(norm) > 40:
                    docs[f"{level.parent.name}/{level.name}"] = norm
        for (a, ta), (b, tb) in combinations(docs.items(), 2):
            sm = difflib.SequenceMatcher(None, ta, tb, autojunk=False)
            if sm.real_quick_ratio() < limit or sm.quick_ratio() < limit:
                continue
            ratio = sm.ratio()
            if ratio >= limit:
                print(f"SIMILAR    {ratio:.2f} {name}: {a} ~ {b}")
                flagged += 1

    print(f"\n{flagged} issue(s) in {len(levels)} levels")
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
