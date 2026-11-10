#!/usr/bin/env python3
"""Check that every level is actually playable.

For each level:
  1. setup.sh runs without error (and without hanging)
  2. validate.sh FAILS on the fresh sandbox (no free passes)
  3. solution.sh runs, then validate.sh PASSES (the level is solvable)
  4. the level folder has mission.yaml (valid JSON with the required keys),
     3 hints and a debrief

Usage:
  scripts/test_levels.py                         # all levels
  scripts/test_levels.py module-4-processes      # one module (substring match)
  scripts/test_levels.py module-4 module-5 -v    # several, show validator output
  scripts/test_levels.py --json report.json      # machine-readable report

Run it on Linux. scripts/test-levels-docker.sh runs it in an Ubuntu container
as a non-root user, which is the reference environment.
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from engine.runner import kill_sandbox_processes, reset_sandbox, run_setup, run_solution, run_validate  # noqa: E402

REQUIRED_MISSION_KEYS = ("name", "description", "objective", "xp", "difficulty", "concepts")
DIFFICULTIES = ("beginner", "intermediate", "advanced", "expert")


def level_dirs(filters: list[str]) -> list[Path]:
    def num(p: Path) -> int:
        parts = p.name.split("-")
        return int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 9999

    mods = sorted((REPO / "modules").iterdir(), key=num)
    out = []
    for mod in mods:
        if not mod.is_dir():
            continue
        for lvl in sorted(mod.iterdir(), key=num):
            if not (lvl / "mission.yaml").exists():
                continue
            ident = f"{mod.name}/{lvl.name}"
            if filters and not any(f in ident for f in filters):
                continue
            out.append(lvl)
    return out


def lint(level: Path) -> list[str]:
    problems = []
    try:
        mission = json.loads((level / "mission.yaml").read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"mission.yaml is not valid JSON: {exc}"]
    for key in REQUIRED_MISSION_KEYS:
        if key not in mission:
            problems.append(f"mission.yaml missing '{key}'")
    if mission.get("difficulty") not in DIFFICULTIES:
        problems.append(f"unknown difficulty {mission.get('difficulty')!r}")
    for i in (1, 2, 3):
        hint = level / f"hint-{i}.txt"
        if not hint.exists() or not hint.read_text(encoding="utf-8").strip():
            problems.append(f"hint-{i}.txt missing or empty")
    if not (level / "debrief.md").exists():
        problems.append("debrief.md missing")
    for script in ("setup.sh", "validate.sh"):
        if not (level / script).exists():
            problems.append(f"{script} missing")
    return problems


def check(level: Path, root: Path, verbose: bool) -> dict:
    ident = f"{level.parent.name}/{level.name}"
    sandbox = root / level.parent.name / level.name
    result = {"level": ident, "status": "pass", "problems": []}
    problems = result["problems"]
    problems += lint(level)

    reset_sandbox(sandbox)
    code, out = run_setup(level, sandbox)
    if code != 0:
        problems.append(f"setup.sh failed ({code}): {out[-300:]}")
    else:
        ok, msg = run_validate(level, sandbox)
        if ok:
            problems.append(f"passes before any work was done: {msg.splitlines()[-1] if msg else ''}")
        elif verbose:
            result["fresh_validate"] = msg

        if not (level / "solution.sh").exists():
            result["status"] = "no-solution"
        else:
            reset_sandbox(sandbox)
            run_setup(level, sandbox)
            scode, sout = run_solution(level, sandbox)
            ok, msg = run_validate(level, sandbox)
            if not ok:
                tail = msg.splitlines()[-1] if msg else ""
                problems.append(f"solution.sh (exit {scode}) does not pass validate.sh: {tail}")
                if verbose:
                    result["solution_output"] = sout[-500:]

    kill_sandbox_processes(sandbox)
    if problems:
        result["status"] = "fail"
    return result


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filters", nargs="*", help="only test levels whose id contains one of these")
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("--json", type=Path, help="write a JSON report here")
    ap.add_argument("--allow-missing-solution", action="store_true",
                    help="do not count levels without solution.sh as failures")
    args = ap.parse_args()

    levels = level_dirs(args.filters)
    if not levels:
        print("No levels matched.")
        return 1

    results = []
    with tempfile.TemporaryDirectory(prefix="lm-test-") as tmp:
        for i, level in enumerate(levels, 1):
            r = check(level, Path(tmp), args.verbose)
            results.append(r)
            mark = {"pass": "PASS", "fail": "FAIL", "no-solution": "NOSOL"}[r["status"]]
            print(f"[{i:3}/{len(levels)}] {mark:5} {r['level']}", flush=True)
            for p in r["problems"]:
                print(f"           - {p}")
            if args.verbose:
                for key in ("fresh_validate", "solution_output"):
                    if r.get(key):
                        print(f"           {key}: {r[key]}")

    counts = {s: sum(r["status"] == s for r in results) for s in ("pass", "fail", "no-solution")}
    print(f"\n{counts['pass']} pass, {counts['fail']} fail, {counts['no-solution']} without solution.sh "
          f"({len(results)} levels)")
    if args.json:
        args.json.write_text(json.dumps(results, indent=1), encoding="utf-8")
    bad = counts["fail"] + (0 if args.allow_missing_solution else counts["no-solution"])
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
