#!/usr/bin/env python3
"""Shared setup/validate runtime for generated LinuxMissions levels."""
from __future__ import annotations

import json
import os
import stat
import sys
import tarfile
from pathlib import Path


def load_level(level_dir: Path) -> dict:
    return json.loads((level_dir / "level.json").read_text(encoding="utf-8"))


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
    ensure_parent(path)
    path.write_text(content, encoding="utf-8")


def write_lines(path: Path, lines: list[str]) -> None:
    text = "\n".join(lines)
    if lines:
        text += "\n"
    write_text(path, text)


def relative_entries(paths: list[str]) -> list[str]:
    return sorted(path.rstrip("/") for path in paths)


def setup_extract_match(task: dict, sandbox: Path) -> None:
    write_lines(sandbox / task["input_file"], task["lines"])


def validate_extract_match(task: dict, sandbox: Path) -> tuple[bool, str]:
    output = sandbox / task["output_file"]
    if not output.exists():
        return False, f"{task['output_file']} not found"
    actual = output.read_text(encoding="utf-8").splitlines()
    expected = task["expected_lines"]
    if actual != expected:
        return False, f"{task['output_file']} does not contain the expected filtered lines"
    return True, f"{task['output_file']} contains the expected matches"


def setup_count_pattern(task: dict, sandbox: Path) -> None:
    write_lines(sandbox / task["input_file"], task["lines"])


def validate_count_pattern(task: dict, sandbox: Path) -> tuple[bool, str]:
    output = sandbox / task["output_file"]
    if not output.exists():
        return False, f"{task['output_file']} not found"
    actual = output.read_text(encoding="utf-8").strip()
    expected = str(task["expected_value"])
    if actual != expected:
        return False, f"Expected {expected} in {task['output_file']}, found {actual or 'empty output'}"
    return True, f"{task['output_file']} contains the expected count {expected}"


def setup_sort_unique(task: dict, sandbox: Path) -> None:
    write_lines(sandbox / task["input_file"], task["lines"])


def validate_sort_unique(task: dict, sandbox: Path) -> tuple[bool, str]:
    output = sandbox / task["output_file"]
    if not output.exists():
        return False, f"{task['output_file']} not found"
    actual = output.read_text(encoding="utf-8").splitlines()
    if actual != task["expected_lines"]:
        return False, f"{task['output_file']} is not sorted and unique as expected"
    return True, f"{task['output_file']} is correctly sorted and deduplicated"


def setup_extract_field(task: dict, sandbox: Path) -> None:
    write_lines(sandbox / task["input_file"], task["lines"])


def validate_extract_field(task: dict, sandbox: Path) -> tuple[bool, str]:
    output = sandbox / task["output_file"]
    if not output.exists():
        return False, f"{task['output_file']} not found"
    actual = output.read_text(encoding="utf-8").splitlines()
    if actual != task["expected_lines"]:
        return False, f"{task['output_file']} does not contain the expected extracted field values"
    return True, f"{task['output_file']} contains the expected extracted values"


def setup_replace_text(task: dict, sandbox: Path) -> None:
    write_text(sandbox / task["input_file"], task["original_text"])


def validate_replace_text(task: dict, sandbox: Path) -> tuple[bool, str]:
    output = sandbox / task["output_file"]
    if not output.exists():
        return False, f"{task['output_file']} not found"
    actual = output.read_text(encoding="utf-8")
    if actual != task["expected_text"]:
        return False, f"{task['output_file']} does not contain the expected replacement result"
    return True, f"{task['output_file']} contains the expected edited content"


def setup_create_tree_move(task: dict, sandbox: Path) -> None:
    for relative_path, content in task["files"].items():
        write_text(sandbox / relative_path, content)


def validate_create_tree_move(task: dict, sandbox: Path) -> tuple[bool, str]:
    target = sandbox / task["target_path"]
    if not target.exists():
        return False, f"{task['target_path']} not found"
    if target.read_text(encoding="utf-8") != task["target_text"]:
        return False, f"{task['target_path']} has unexpected content"
    for removed in task.get("removed_paths", []):
        if (sandbox / removed).exists():
            return False, f"{removed} should have been moved away"
    return True, f"{task['target_path']} is in the correct place"


def setup_head_tail(task: dict, sandbox: Path) -> None:
    write_lines(sandbox / task["input_file"], task["lines"])


def validate_head_tail(task: dict, sandbox: Path) -> tuple[bool, str]:
    first_output = sandbox / task["first_output"]
    last_output = sandbox / task["last_output"]
    if not first_output.exists():
        return False, f"{task['first_output']} not found"
    if not last_output.exists():
        return False, f"{task['last_output']} not found"
    first_lines = first_output.read_text(encoding="utf-8").splitlines()
    last_lines = last_output.read_text(encoding="utf-8").splitlines()
    if first_lines != task["expected_first"]:
        return False, f"{task['first_output']} does not contain the expected first lines"
    if last_lines != task["expected_last"]:
        return False, f"{task['last_output']} does not contain the expected last lines"
    return True, "Head/tail outputs are correct"


def setup_find_and_delete(task: dict, sandbox: Path) -> None:
    for relative_path, content in task["files"].items():
        write_text(sandbox / relative_path, content)


def validate_find_and_delete(task: dict, sandbox: Path) -> tuple[bool, str]:
    for removed in task["remove_paths"]:
        if (sandbox / removed).exists():
            return False, f"{removed} still exists"
    for keep in task["keep_paths"]:
        if not (sandbox / keep).exists():
            return False, f"{keep} should still exist"
    return True, "Only the intended files were removed"


def setup_symlink_target(task: dict, sandbox: Path) -> None:
    write_text(sandbox / task["target_path"], task["target_text"])


def validate_symlink_target(task: dict, sandbox: Path) -> tuple[bool, str]:
    link_path = sandbox / task["link_path"]
    target_path = (sandbox / task["target_path"]).resolve()
    if not link_path.exists() and not link_path.is_symlink():
        return False, f"{task['link_path']} not found"
    if not link_path.is_symlink():
        return False, f"{task['link_path']} is not a symbolic link"
    if link_path.resolve() != target_path:
        return False, f"{task['link_path']} does not point to the expected target"
    return True, f"{task['link_path']} points to the expected file"


def setup_archive_create(task: dict, sandbox: Path) -> None:
    for relative_path, content in task["source_files"].items():
        write_text(sandbox / relative_path, content)


def validate_archive_create(task: dict, sandbox: Path) -> tuple[bool, str]:
    archive = sandbox / task["archive_path"]
    if not archive.exists():
        return False, f"{task['archive_path']} not found"
    try:
        with tarfile.open(archive, "r:*") as tar:
            names = relative_entries(tar.getnames())
    except tarfile.TarError:
        return False, f"{task['archive_path']} is not a readable archive"
    required = relative_entries(task["required_entries"])
    for entry in required:
        if entry not in names:
            return False, f"{entry} missing from {task['archive_path']}"
    return True, f"{task['archive_path']} contains the expected files"


def setup_archive_extract(task: dict, sandbox: Path) -> None:
    archive = sandbox / task["archive_path"]
    ensure_parent(archive)
    with tarfile.open(archive, "w:gz") as tar:
        staging = sandbox / ".staging_extract"
        staging.mkdir(parents=True, exist_ok=True)
        for relative_path, content in task["archived_files"].items():
            staged_file = staging / relative_path
            write_text(staged_file, content)
            tar.add(staged_file, arcname=relative_path)


def validate_archive_extract(task: dict, sandbox: Path) -> tuple[bool, str]:
    for relative_path, content in task["required_files"].items():
        output = sandbox / relative_path
        if not output.exists():
            return False, f"{relative_path} not found after extraction"
        if output.read_text(encoding="utf-8") != content:
            return False, f"{relative_path} has unexpected content after extraction"
    return True, "Archive contents were extracted correctly"


def setup_chmod_mode(task: dict, sandbox: Path) -> None:
    path = sandbox / task["file_path"]
    write_text(path, task["content"])
    os.chmod(path, task.get("initial_mode", 0o644))


def validate_chmod_mode(task: dict, sandbox: Path) -> tuple[bool, str]:
    path = sandbox / task["file_path"]
    if not path.exists():
        return False, f"{task['file_path']} not found"
    actual = stat.S_IMODE(path.stat().st_mode)
    expected = int(str(task["mode"]), 8)
    if actual != expected:
        return False, f"{task['file_path']} mode is {oct(actual)[2:]}, expected {oct(expected)[2:]}"
    return True, f"{task['file_path']} has mode {oct(expected)[2:]}"


def setup_run_script_token(task: dict, sandbox: Path) -> None:
    script_path = sandbox / task["script_path"]
    token_path = sandbox / task["token_path"]
    script_body = (
        "#!/bin/bash\n"
        f"printf '%s\\n' '{task['token']}' > '{token_path}'\n"
    )
    write_text(script_path, script_body)
    os.chmod(script_path, task.get("initial_mode", 0o640))


def validate_run_script_token(task: dict, sandbox: Path) -> tuple[bool, str]:
    token_path = sandbox / task["token_path"]
    if not token_path.exists():
        return False, f"{task['token_path']} not found"
    if token_path.read_text(encoding="utf-8").strip() != task["token"]:
        return False, f"{task['token_path']} does not contain the expected token"
    return True, f"{task['token_path']} contains the expected token"


def setup_loop_generate(task: dict, sandbox: Path) -> None:
    root = sandbox / task["root_dir"]
    root.mkdir(parents=True, exist_ok=True)
    if task.get("seed_file"):
        write_text(root / task["seed_file"], task.get("seed_content", ""))


def validate_loop_generate(task: dict, sandbox: Path) -> tuple[bool, str]:
    root = sandbox / task["root_dir"]
    for item in task["expected_files"]:
        path = root / item["path"]
        if not path.exists():
            return False, f"{path.relative_to(sandbox)} not found"
        if path.read_text(encoding="utf-8") != item["content"]:
            return False, f"{path.relative_to(sandbox)} has unexpected content"
    return True, "Generated files match the expected sequence"


def setup_awk_sum(task: dict, sandbox: Path) -> None:
    write_lines(sandbox / task["input_file"], task["lines"])


def validate_awk_sum(task: dict, sandbox: Path) -> tuple[bool, str]:
    output = sandbox / task["output_file"]
    if not output.exists():
        return False, f"{task['output_file']} not found"
    actual = output.read_text(encoding="utf-8").strip()
    expected = str(task["expected_sum"])
    if actual != expected:
        return False, f"Expected sum {expected}, found {actual or 'empty output'}"
    return True, f"{task['output_file']} contains the expected sum {expected}"


def setup_disk_report(task: dict, sandbox: Path) -> None:
    for name, size in task["dirs"].items():
        target_dir = sandbox / name
        target_dir.mkdir(parents=True, exist_ok=True)
        write_text(target_dir / "payload.bin", "X" * size)


def validate_disk_report(task: dict, sandbox: Path) -> tuple[bool, str]:
    output = sandbox / task["output_file"]
    if not output.exists():
        return False, f"{task['output_file']} not found"
    actual = output.read_text(encoding="utf-8").strip()
    if actual != task["expected_dir"]:
        return False, f"Expected largest directory {task['expected_dir']}, found {actual or 'empty output'}"
    return True, f"{task['output_file']} identifies {task['expected_dir']} as the largest directory"


def setup_cron_line(task: dict, sandbox: Path) -> None:
    if task.get("note"):
        write_text(sandbox / "README", task["note"] + "\n")


def validate_cron_line(task: dict, sandbox: Path) -> tuple[bool, str]:
    output = sandbox / task["output_file"]
    if not output.exists():
        return False, f"{task['output_file']} not found"
    lines = [line.strip() for line in output.read_text(encoding="utf-8").splitlines() if line.strip()]
    if task["expected_line"] not in lines:
        return False, f"{task['expected_line']} not found in {task['output_file']}"
    return True, f"{task['output_file']} contains the expected schedule entry"


TASKS = {
    "extract_match": (setup_extract_match, validate_extract_match),
    "count_pattern": (setup_count_pattern, validate_count_pattern),
    "sort_unique": (setup_sort_unique, validate_sort_unique),
    "extract_field": (setup_extract_field, validate_extract_field),
    "replace_text": (setup_replace_text, validate_replace_text),
    "create_tree_move": (setup_create_tree_move, validate_create_tree_move),
    "head_tail": (setup_head_tail, validate_head_tail),
    "find_and_delete": (setup_find_and_delete, validate_find_and_delete),
    "symlink_target": (setup_symlink_target, validate_symlink_target),
    "archive_create": (setup_archive_create, validate_archive_create),
    "archive_extract": (setup_archive_extract, validate_archive_extract),
    "chmod_mode": (setup_chmod_mode, validate_chmod_mode),
    "run_script_token": (setup_run_script_token, validate_run_script_token),
    "loop_generate": (setup_loop_generate, validate_loop_generate),
    "awk_sum": (setup_awk_sum, validate_awk_sum),
    "disk_report": (setup_disk_report, validate_disk_report),
    "cron_line": (setup_cron_line, validate_cron_line),
}


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: generated_level_runtime.py <setup|validate> <level_dir> <sandbox>")
        return 2

    mode = sys.argv[1]
    level_dir = Path(sys.argv[2]).resolve()
    sandbox = Path(sys.argv[3]).resolve()
    config = load_level(level_dir)
    task = config["task"]
    task_type = task["type"]

    if task_type not in TASKS:
        print(f"❌ FAIL: unsupported generated task type {task_type}")
        return 1

    setup_fn, validate_fn = TASKS[task_type]

    if mode == "setup":
        setup_fn(task, sandbox)
        return 0

    if mode == "validate":
        passed, message = validate_fn(task, sandbox)
        print(("✅ PASS: " if passed else "❌ FAIL: ") + message)
        return 0 if passed else 1

    print(f"unknown mode: {mode}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
