#!/usr/bin/env python3
"""Generate an expanded LinuxMissions curriculum up to 500 total levels."""
from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MODULES_DIR = REPO / "modules"
RUNTIME_RELATIVE = "../../../scripts/generated_level_runtime.py"

XP_BY_DIFFICULTY = {
    "beginner": 100,
    "intermediate": 150,
    "advanced": 200,
    "expert": 300,
}

TIME_BY_DIFFICULTY = {
    "beginner": "5m",
    "intermediate": "8m",
    "advanced": "12m",
    "expert": "15m",
}

PLAN_24 = [
    "create_tree_move",
    "extract_match",
    "count_pattern",
    "sort_unique",
    "extract_field",
    "replace_text",
    "head_tail",
    "find_and_delete",
    "symlink_target",
    "archive_create",
    "archive_extract",
    "chmod_mode",
    "run_script_token",
    "loop_generate",
    "awk_sum",
    "disk_report",
    "cron_line",
    "extract_match",
    "replace_text",
    "sort_unique",
    "create_tree_move",
    "extract_field",
    "archive_create",
    "chmod_mode",
]

PLAN_30 = PLAN_24 + [
    "run_script_token",
    "loop_generate",
    "find_and_delete",
    "archive_extract",
    "awk_sum",
    "disk_report",
]

MODULE_SPECS = [
    {
        "name": "module-9-shell-environment",
        "theme": "shell environment",
        "focuses": [
            "shell-startup", "pwd-cd", "variables", "export", "path", "quoting",
            "globbing", "brace-expansion", "command-substitution", "aliases", "history",
            "redirection", "pipes", "tee", "xargs", "env", "printenv", "unset", "source",
            "shell-options", "test-brackets", "case", "here-strings", "here-docs",
        ],
    },
    {
        "name": "module-10-archives-compression",
        "theme": "archives and compression",
        "focuses": [
            "tar-create", "tar-extract", "gzip", "gunzip", "bzip2", "bunzip2",
            "xz", "unxz", "zip", "unzip", "cpio", "split",
            "cat-reassemble", "sha256sum", "md5sum", "file", "stat", "du",
            "df", "lsblk", "mount-notes", "rsync-basics", "backup-rotation", "archive-audit",
        ],
    },
    {
        "name": "module-11-find-and-pipelines",
        "theme": "search and pipelines",
        "focuses": [
            "find-name", "find-type", "find-size", "find-mtime", "find-exec", "grep-fixed",
            "grep-regex", "grep-invert", "grep-count", "grep-context", "cut-fields", "paste-columns",
            "join-files", "comm-compare", "sort-keys", "uniq-count", "tr-translate", "tr-delete",
            "sed-print", "sed-substitute", "awk-patterns", "awk-fields", "awk-sum", "pipeline-report",
        ],
    },
    {
        "name": "module-12-users-and-groups",
        "theme": "users and groups",
        "focuses": [
            "passwd-file", "group-file", "id-command", "whoami", "groups-command", "su-notes",
            "sudoers-audit", "home-layout", "skeleton-files", "umask-basics", "chage-review", "passwd-status",
            "login-shells", "etc-profile", "bashrc", "motd", "lastlog-audit", "account-locks",
            "group-membership", "shared-dir-policy", "secure-tempfiles", "ownership-audit", "permission-matrix", "onboarding-checklist",
        ],
    },
    {
        "name": "module-13-services-and-logs",
        "theme": "services and logs",
        "focuses": [
            "systemctl-status", "systemctl-enable", "systemctl-disable", "systemctl-restart", "journalctl-errors", "journalctl-unit",
            "dmesg-basics", "syslog-triage", "auth-log", "nginx-log", "app-log-rotation", "tail-follow",
            "less-navigation", "service-envfiles", "proc-maps", "proc-cpuinfo", "proc-meminfo", "hostnamectl",
            "timedatectl", "localectl", "unit-files", "service-dependencies", "incident-summary", "failure-timeline",
        ],
    },
    {
        "name": "module-14-storage-and-backups",
        "theme": "storage and backups",
        "focuses": [
            "partitions", "mkfs-planning", "fstab-review", "mountpoints", "bind-mounts", "tmpfs",
            "sparse-files", "dd-imaging", "sync-command", "rsync-archive", "rsync-delete", "hard-links",
            "symbolic-links", "inodes", "quotas", "filesystem-labels", "blkid", "backup-manifests",
            "checksum-verify", "restore-drill", "snapshot-notes", "archive-prune", "data-retention", "recovery-bundle",
        ],
    },
    {
        "name": "module-15-scheduling-and-jobs",
        "theme": "scheduling and jobs",
        "focuses": [
            "cron-syntax", "crontab-edit", "cron-daily", "cron-hourly", "at-jobs", "batch-jobs",
            "systemd-timers", "nohup", "bg-fg", "jobs-builtin", "disown", "sleep-delay",
            "watch-command", "timeout", "flock-locks", "logrotate", "maintenance-window", "recurring-backups",
            "cleanup-jobs", "report-jobs", "timer-audit", "uptime-planning", "shift-handovers", "automation-calendar",
        ],
    },
    {
        "name": "module-16-security-auditing",
        "theme": "security auditing",
        "focuses": [
            "chmod-basics", "chmod-octal", "chmod-symbolic", "sticky-bit", "sgid-dir", "suid-audit",
            "umask-hardening", "ssh-config", "known-hosts", "authorized-keys", "gpg-checks", "sha256-verify",
            "file-permissions", "secret-scanning", "env-secrets", "history-safety", "temp-file-risks", "sudo-review",
            "path-hijack", "shellshock-checks", "service-user", "audit-summary", "incident-notes", "hardening-checklist",
        ],
    },
    {
        "name": "module-17-monitoring-and-performance",
        "theme": "monitoring and performance",
        "focuses": [
            "top-reading", "ps-sorting", "free-memory", "vmstat-review", "iostat-notes", "uptime-load",
            "nice-values", "renice-plan", "ionice-notes", "pidof", "pgrep", "pkill",
            "lsof-basics", "ss-listen", "netstat-legacy", "df-hotspots", "du-ranking", "journal-errors",
            "log-noise", "cpu-hotspots", "memory-leaks", "open-files", "watch-loops", "triage-report",
        ],
    },
    {
        "name": "module-18-configuration-editing",
        "theme": "configuration editing",
        "focuses": [
            "cat-review", "less-review", "sed-inplace", "awk-rewrite", "cut-columns", "paste-config",
            "split-configs", "diff-review", "patch-apply", "envsubst", "templates", "ini-files",
            "yaml-basics", "json-notes", "hosts-file", "resolv-conf", "ssh-config-edit", "profile-d",
            "aliases-file", "exports-file", "prompt-customize", "vim-modes", "nano-shortcuts", "config-audit",
        ],
    },
    {
        "name": "module-19-network-troubleshooting",
        "theme": "network troubleshooting",
        "focuses": [
            "ip-addr", "ip-route", "ping-host", "traceroute-notes", "dig-records", "nslookup",
            "host-command", "curl-headers", "wget-mirror", "ss-ports", "nc-connect", "telnet-legacy",
            "arp-cache", "resolv-debug", "hosts-override", "proxy-vars", "http-status", "tls-notes",
            "interface-state", "mtu-troubles", "route-priority", "subnet-math", "dns-triage", "outage-brief",
        ],
    },
    {
        "name": "module-20-package-and-release-ops",
        "theme": "package and release operations",
        "focuses": [
            "apt-search", "apt-install", "apt-remove", "apt-update", "apt-upgrade", "apt-cache",
            "dpkg-query", "dpkg-files", "snap-notes", "flatpak-notes", "repo-keys", "sources-list",
            "package-audit", "changelog-review", "version-compare", "semver-basics", "release-notes", "artifact-layout",
            "install-manifest", "dependency-tree", "package-verify", "service-reload", "rollback-plan", "promotion-checks",
        ],
    },
    {
        "name": "module-21-shell-automation",
        "theme": "shell automation",
        "focuses": [
            "shebang", "exit-codes", "positional-params", "getopts", "functions", "arrays",
            "loops-for", "loops-while", "conditionals-if", "case-esac", "test-operators", "string-ops",
            "arithmetic", "command-substitution", "process-substitution", "heredoc", "traps", "set-e",
            "set-u", "pipefail", "debug-xtrace", "modules-source", "reusable-scripts", "automation-summary",
        ],
    },
    {
        "name": "module-22-data-processing",
        "theme": "data processing",
        "focuses": [
            "csv-cleanup", "report-headers", "column-extract", "row-filter", "numeric-sort", "stable-sort",
            "uniq-count", "aggregation", "histogram", "frequency-table", "timestamps", "date-format",
            "cut-delimiters", "paste-merge", "join-keys", "comm-diff", "records-split", "multiline-fixes",
            "whitespace-trim", "tabular-output", "summary-totals", "anomaly-detection", "report-export", "data-audit",
        ],
    },
    {
        "name": "module-23-boot-and-recovery",
        "theme": "boot and recovery",
        "focuses": [
            "grub-notes", "initramfs-notes", "rescue-shell", "single-user", "fsck-plan", "recovery-log",
            "kernel-versions", "uname-a", "lsmod-review", "modprobe-notes", "dmesg-errors", "boot-order",
            "journal-boot", "emergency-target", "fstab-failures", "network-recovery", "password-reset-notes", "snapshot-restore",
            "backup-boot", "broken-symlink-audit", "missing-library", "path-recovery", "login-recovery", "reboot-checklist",
        ],
    },
    {
        "name": "module-24-system-inspection",
        "theme": "system inspection",
        "focuses": [
            "uname", "hostname", "who", "w-command", "last-command", "env-print",
            "os-release", "cpu-info", "mem-info", "mounts", "block-devices", "pci-review",
            "usb-review", "processes-tree", "open-ports", "listening-services", "kernel-tuning", "sysctl-review",
            "limits-conf", "cgroups-notes", "namespaces-notes", "tempdirs", "file-types", "inspection-report",
        ],
    },
    {
        "name": "module-25-linux-toolbelt",
        "theme": "linux toolbelt",
        "focuses": [
            "tee-append", "xargs-null", "printf-format", "seq-command", "yes-head", "nl-numbering",
            "tac-reverse", "rev-text", "fold-wrap", "fmt-fill", "expand-tabs", "unexpand-tabs",
            "shuf-random", "split-by-lines", "csplit-pattern", "strings-binary", "od-hexdump", "xxd-review",
            "base64-encode", "base64-decode", "time-command", "script-capture", "expect-notes", "toolbelt-summary",
        ],
    },
    {
        "name": "module-26-linux-wargames",
        "theme": "linux war games",
        "focuses": [
            "broken-backup", "noisy-logs", "corrupt-config", "archive-rescue", "permission-chaos", "report-pipeline",
            "secret-hunt", "cleanup-sprint", "checksum-race", "release-rollback", "storage-panic", "cron-mess",
            "user-audit", "link-labyrinth", "config-storm", "disk-hotspot", "path-mystery", "grep-gauntlet",
            "awk-arena", "sed-surgery", "tar-tunnel", "restore-relay", "service-failure", "routing-puzzle",
            "package-panic", "process-swarm", "forensic-dump", "boot-scare", "log-maze", "final-incident",
        ],
    },
]


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def titleize(value: str) -> str:
    return value.replace("-", " ").replace("etc ", "/etc/").title()


def difficulty_for(index: int, total: int, module_name: str) -> str:
    if module_name == "module-26-linux-wargames":
        if index <= 10:
            return "intermediate"
        if index <= 22:
            return "advanced"
        return "expert"
    if index <= total // 3:
        return "beginner"
    if index <= (2 * total) // 3:
        return "intermediate"
    return "advanced"


def task_concepts(task_type: str) -> list[str]:
    return {
        "create_tree_move": ["mkdir", "mv", "cp"],
        "extract_match": ["grep", "output redirection"],
        "count_pattern": ["grep", "wc", "redirection"],
        "sort_unique": ["sort", "uniq"],
        "extract_field": ["cut", "awk"],
        "replace_text": ["sed", "redirection"],
        "head_tail": ["head", "tail"],
        "find_and_delete": ["find", "rm"],
        "symlink_target": ["ln", "symbolic links"],
        "archive_create": ["tar", "compression"],
        "archive_extract": ["tar", "archive extraction"],
        "chmod_mode": ["chmod", "permissions"],
        "run_script_token": ["chmod", "bash"],
        "loop_generate": ["for", "seq", "printf"],
        "awk_sum": ["awk", "numeric aggregation"],
        "disk_report": ["du", "sort"],
        "cron_line": ["cron", "crontab syntax"],
    }[task_type]


def mission_description(theme: str, focus: str) -> str:
    return f"In the {theme} lab, a task related to {titleize(focus)} needs cleanup before the handoff."


def debrief_markdown(mission_name: str, focus: str, commands: list[str], hints: list[str]) -> str:
    command_block = "\n".join(commands)
    practiced = "\n".join(
        [
            f"- This level focused on **{titleize(focus)}** in a safe sandbox.",
            f"- The shortest path usually combines `{commands[0].split()[0]}` with careful redirection or inspection.",
            "- Keep intermediate outputs small and verify them before moving on.",
        ]
    )
    return (
        f"# {mission_name}\n\n"
        "## What you practiced\n"
        f"{practiced}\n\n"
        "## Commands to remember\n"
        "```bash\n"
        f"{command_block}\n"
        "```\n\n"
        "## Key insight\n"
        f"- Start with inspection, then apply the smallest command that achieves the goal.\n"
        f"- Hint ladder summary: {hints[0]}\n"
    )


def shell_wrappers() -> tuple[str, str]:
    setup = (
        "#!/bin/bash\n"
        'SANDBOX="$1"\n'
        'LEVEL_DIR="$(cd "$(dirname "$0")" && pwd)"\n'
        f'python3 "$LEVEL_DIR/{RUNTIME_RELATIVE}" setup "$LEVEL_DIR" "$SANDBOX"\n'
    )
    validate = (
        "#!/bin/bash\n"
        'SANDBOX="$1"\n'
        'LEVEL_DIR="$(cd "$(dirname "$0")" && pwd)"\n'
        f'python3 "$LEVEL_DIR/{RUNTIME_RELATIVE}" validate "$LEVEL_DIR" "$SANDBOX"\n'
    )
    return setup, validate


def build_create_tree_move(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    source = f"inbox/{slug}.txt"
    target = f"organized/{slug}/{slug}-notes.txt"
    content = f"{titleize(focus)} checklist for {theme}\n"
    objective = f"Create the target directory and move {source} to {target}"
    hints = [
        f"Inspect the sandbox, then create the missing path for {target}.",
        f"`mkdir -p organized/{slug}` followed by `mv {source} {target}` is enough.",
        f"Example: `mkdir -p organized/{slug} && mv {source} {target}`",
    ]
    commands = [
        "mkdir -p path/to/dir",
        "mv source target",
        "cp source target",
    ]
    return {
        "subtitle": "Path Realignment",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "create_tree_move",
            "files": {source: content},
            "target_path": target,
            "target_text": content,
            "removed_paths": [source],
        },
    }


def build_extract_match(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    input_file = f"{slug}.log"
    needle = titleize(focus).split()[0].upper()
    lines = [
        f"INFO preparing {focus}",
        f"ALERT {needle} drift detected",
        f"INFO collecting extra context",
        f"ALERT {needle} rollback required",
        f"INFO handoff complete",
    ]
    expected = [line for line in lines if "ALERT" in line]
    objective = f"Write every alert line from {input_file} into alerts.txt"
    hints = [
        f"Look for a filtering command that keeps only the alert lines in {input_file}.",
        "Use grep with a literal pattern like `ALERT` and redirect the result to `alerts.txt`.",
        f"Example: `grep 'ALERT' {input_file} > alerts.txt`",
    ]
    commands = [
        "grep 'ALERT' file.log",
        "grep -n PATTERN file.log",
        "grep -v PATTERN file.log",
    ]
    return {
        "subtitle": "Alert Filter",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "extract_match",
            "input_file": input_file,
            "lines": lines,
            "pattern": "ALERT",
            "output_file": "alerts.txt",
            "expected_lines": expected,
        },
    }


def build_count_pattern(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    input_file = f"{slug}-events.txt"
    lines = [
        "ok", "warn", "ok", "error", "ok", "error", "ok", "ok",
    ]
    objective = f"Count how many times `ok` appears in {input_file} and write the number to ok-count.txt"
    hints = [
        f"Count matching lines instead of copying them out by hand.",
        "A grep count or grep piped into wc can produce the number you need.",
        f"Example: `grep -c '^ok$' {input_file} > ok-count.txt`",
    ]
    commands = [
        "grep -c '^pattern$' file.txt",
        "grep PATTERN file.txt | wc -l",
        "wc -l file.txt",
    ]
    return {
        "subtitle": "Event Counter",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "count_pattern",
            "input_file": input_file,
            "lines": lines,
            "pattern": "ok",
            "output_file": "ok-count.txt",
            "expected_value": 5,
        },
    }


def build_sort_unique(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    input_file = f"{slug}-raw.txt"
    lines = ["zeta", "alpha", "beta", "alpha", "gamma", "beta"]
    expected = sorted(set(lines))
    objective = f"Create unique-sorted.txt from {input_file} with sorted unique values"
    hints = [
        "This is a sorting task followed by deduplication.",
        "Pipe `sort` into `uniq` and redirect the result to `unique-sorted.txt`.",
        f"Example: `sort {input_file} | uniq > unique-sorted.txt`",
    ]
    commands = [
        "sort file.txt",
        "sort file.txt | uniq",
        "uniq -c sorted.txt",
    ]
    return {
        "subtitle": "Noise Dedup",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "sort_unique",
            "input_file": input_file,
            "lines": lines,
            "output_file": "unique-sorted.txt",
            "expected_lines": expected,
        },
    }


def build_extract_field(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    input_file = f"{slug}-report.csv"
    lines = [
        "service,owner,priority",
        "api,alex,high",
        "worker,mina,medium",
        "db,sofia,critical",
    ]
    expected = ["owner", "alex", "mina", "sofia"]
    objective = f"Extract the second column from {input_file} into owners.txt"
    hints = [
        "This is a delimiter-based column extraction task.",
        "Use `cut -d, -f2` or an awk equivalent and save the result to `owners.txt`.",
        f"Example: `cut -d, -f2 {input_file} > owners.txt`",
    ]
    commands = [
        "cut -d, -f2 file.csv",
        "awk -F, '{print $2}' file.csv",
        "column -s, -t file.csv",
    ]
    return {
        "subtitle": "Field Extract",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "extract_field",
            "input_file": input_file,
            "lines": lines,
            "delimiter": ",",
            "field_index": 2,
            "output_file": "owners.txt",
            "expected_lines": expected,
        },
    }


def build_replace_text(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    input_file = f"{slug}.conf"
    original = "MODE=legacy\nRETRIES=1\nMODE=legacy\n"
    expected = "MODE=managed\nRETRIES=1\nMODE=managed\n"
    objective = f"Replace every `MODE=legacy` entry in {input_file} and save the fixed result to fixed.conf"
    hints = [
        "You need a stream editor or another text replacement tool.",
        "Use `sed` to replace `legacy` with `managed`, then redirect the output to `fixed.conf`.",
        f"Example: `sed 's/MODE=legacy/MODE=managed/g' {input_file} > fixed.conf`",
    ]
    commands = [
        "sed 's/old/new/g' file.conf",
        "sed -n '1,20p' file.conf",
        "grep PATTERN file.conf",
    ]
    return {
        "subtitle": "Config Rewrite",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "replace_text",
            "input_file": input_file,
            "original_text": original,
            "old": "MODE=legacy",
            "new": "MODE=managed",
            "output_file": "fixed.conf",
            "expected_text": expected,
        },
    }


def build_head_tail(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    input_file = f"{slug}-history.log"
    lines = [f"entry-{n}" for n in range(1, 13)]
    objective = f"Write the first 3 lines of {input_file} to first3.txt and the last 3 lines to last3.txt"
    hints = [
        "Use one command for the beginning of the file and another for the end.",
        "Save each result into its own file.",
        f"Example: `head -n 3 {input_file} > first3.txt` and `tail -n 3 {input_file} > last3.txt`",
    ]
    commands = [
        "head -n 3 file.log",
        "tail -n 3 file.log",
        "tail -f file.log",
    ]
    return {
        "subtitle": "History Window",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "head_tail",
            "input_file": input_file,
            "lines": lines,
            "first_output": "first3.txt",
            "last_output": "last3.txt",
            "expected_first": lines[:3],
            "expected_last": lines[-3:],
        },
    }


def build_find_and_delete(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    files = {
        f"cleanup/{slug}/keep.txt": "keep\n",
        f"cleanup/{slug}/old-1.tmp": "junk\n",
        f"cleanup/{slug}/old-2.tmp": "junk\n",
        f"cleanup/{slug}/notes.md": "notes\n",
    }
    objective = f"Delete only the `.tmp` files under cleanup/{slug} and leave the other files intact"
    hints = [
        "Use a targeted file search so you do not remove the wrong files.",
        "A `find` command with a name filter plus `-delete` or `-exec rm` works well here.",
        f"Example: `find cleanup/{slug} -name '*.tmp' -delete`",
    ]
    commands = [
        "find dir -name '*.tmp'",
        "find dir -name '*.tmp' -delete",
        "find dir -type f -exec rm {} \\;",
    ]
    return {
        "subtitle": "Cleanup Sweep",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "find_and_delete",
            "files": files,
            "remove_paths": [f"cleanup/{slug}/old-1.tmp", f"cleanup/{slug}/old-2.tmp"],
            "keep_paths": [f"cleanup/{slug}/keep.txt", f"cleanup/{slug}/notes.md"],
        },
    }


def build_symlink_target(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    objective = f"Create current.conf as a symbolic link to releases/{slug}.conf"
    hints = [
        "This task wants a symbolic link, not a copy.",
        "Use `ln -s` so current.conf points at the release file.",
        f"Example: `ln -s releases/{slug}.conf current.conf`",
    ]
    commands = [
        "ln -s target linkname",
        "ls -l current.conf",
        "readlink current.conf",
    ]
    return {
        "subtitle": "Link Repair",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "symlink_target",
            "target_path": f"releases/{slug}.conf",
            "target_text": f"{titleize(focus)} release payload\n",
            "link_path": "current.conf",
        },
    }


def build_archive_create(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    files = {
        f"bundle/{slug}/README.txt": f"{titleize(focus)} bundle\n",
        f"bundle/{slug}/notes.txt": "handoff notes\n",
    }
    archive_path = f"{slug}-backup.tar.gz"
    objective = f"Create {archive_path} containing the files under bundle/{slug}"
    hints = [
        "Use tar with create, gzip, and file flags.",
        "Archive the directory contents without leaving anything out.",
        f"Example: `tar -czf {archive_path} bundle/{slug}`",
    ]
    commands = [
        "tar -czf backup.tar.gz folder/",
        "tar -tf backup.tar.gz",
        "gzip file.txt",
    ]
    return {
        "subtitle": "Backup Bundle",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "archive_create",
            "source_files": files,
            "archive_path": archive_path,
            "required_entries": [f"bundle/{slug}", f"bundle/{slug}/README.txt", f"bundle/{slug}/notes.txt"],
        },
    }


def build_archive_extract(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    archive_path = f"{slug}-restore.tar.gz"
    archived_files = {
        f"restored/{slug}/app.conf": "PORT=8080\nMODE=restored\n",
        f"restored/{slug}/token.txt": f"{slug}-token\n",
    }
    objective = f"Extract {archive_path} so the restored/{slug} directory appears in the sandbox"
    hints = [
        "List the archive if you want to inspect it first, then extract it.",
        "Use tar extraction flags and point at the archive file.",
        f"Example: `tar -xzf {archive_path}`",
    ]
    commands = [
        "tar -tf archive.tar.gz",
        "tar -xzf archive.tar.gz",
        "ls -R restored/",
    ]
    return {
        "subtitle": "Restore Drill",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "archive_extract",
            "archive_path": archive_path,
            "archived_files": archived_files,
            "required_files": archived_files,
        },
    }


def build_chmod_mode(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    mode = "750" if idx % 2 else "640"
    objective = f"Set the mode of {slug}.sh to {mode}"
    hints = [
        "Inspect the current mode first if you want to verify the change.",
        f"Use chmod with octal mode {mode}.",
        f"Example: `chmod {mode} {slug}.sh`",
    ]
    commands = [
        "chmod 750 script.sh",
        "ls -l script.sh",
        "stat -c '%a %n' script.sh",
    ]
    return {
        "subtitle": "Permission Fix",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "chmod_mode",
            "file_path": f"{slug}.sh",
            "content": "#!/bin/bash\necho ready\n",
            "initial_mode": 0o640,
            "mode": mode,
        },
    }


def build_run_script_token(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    script_path = f"jobs/{slug}.sh"
    token_path = f"jobs/{slug}.token"
    token = f"{slug}-done"
    objective = f"Make {script_path} executable, run it, and create the token file it writes"
    hints = [
        "This task usually takes two steps: fix execute permission, then run the script.",
        f"Use `chmod +x {script_path}` and then execute it.",
        f"Example: `chmod +x {script_path} && {script_path}`",
    ]
    commands = [
        "chmod +x script.sh",
        "./script.sh",
        "bash script.sh",
    ]
    return {
        "subtitle": "Script Kickoff",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "run_script_token",
            "script_path": script_path,
            "token_path": token_path,
            "token": token,
            "initial_mode": 0o640,
        },
    }


def build_loop_generate(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    expected = [
        {"path": f"{slug}-1.txt", "content": f"{slug} item 1\n"},
        {"path": f"{slug}-2.txt", "content": f"{slug} item 2\n"},
        {"path": f"{slug}-3.txt", "content": f"{slug} item 3\n"},
    ]
    objective = f"Create three files under generated/ named {slug}-1.txt through {slug}-3.txt with matching numbered content"
    hints = [
        "A short for-loop is the cleanest option here.",
        "Use `seq` or explicit numbers and redirect each line into a separate file.",
        f"Example: `for n in 1 2 3; do printf '{slug} item %s\\n' \"$n\" > generated/{slug}-$n.txt; done`",
    ]
    commands = [
        "for n in 1 2 3; do ...; done",
        "seq 1 3",
        "printf 'value %s\\n' \"$n\"",
    ]
    return {
        "subtitle": "Loop Builder",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "loop_generate",
            "root_dir": "generated",
            "expected_files": expected,
        },
    }


def build_awk_sum(theme: str, focus: str, idx: int) -> dict:
    slug = slugify(focus)
    input_file = f"{slug}-metrics.csv"
    lines = [
        "service,cost",
        "api,12",
        "worker,19",
        "db,24",
        "cache,5",
    ]
    objective = f"Sum the numeric values in the second column of {input_file} and write the total to total.txt"
    hints = [
        "This is a numeric aggregation task.",
        "An awk one-liner can skip the header and add the second field.",
        f"Example: `awk -F, 'NR>1 {{sum += $2}} END {{print sum}}' {input_file} > total.txt`",
    ]
    commands = [
        "awk -F, 'NR>1 {sum += $2} END {print sum}' file.csv",
        "cut -d, -f2 file.csv",
        "paste -sd+ numbers.txt | bc",
    ]
    return {
        "subtitle": "Metric Sum",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "awk_sum",
            "input_file": input_file,
            "lines": lines,
            "output_file": "total.txt",
            "expected_sum": 60,
        },
    }


def build_disk_report(theme: str, focus: str, idx: int) -> dict:
    dirs = {
        "datasets/api": 100,
        "datasets/logs": 180,
        "datasets/cache": 60,
    }
    objective = "Identify the largest directory under datasets and write its relative path to largest.txt"
    hints = [
        "Measure directory sizes before deciding which one is largest.",
        "A du pipeline sorted numerically is a strong fit here.",
        "Example: `du -s datasets/* | sort -n | tail -n 1` and write only the path to largest.txt",
    ]
    commands = [
        "du -s datasets/*",
        "du -sh datasets/* | sort -h",
        "sort -n report.txt | tail -n 1",
    ]
    return {
        "subtitle": "Capacity Report",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "disk_report",
            "dirs": dirs,
            "output_file": "largest.txt",
            "expected_dir": "datasets/logs",
        },
    }


def build_cron_line(theme: str, focus: str, idx: int) -> dict:
    line = "15 2 * * * /usr/local/bin/nightly-check"
    objective = "Create crontab.txt containing the nightly-check schedule line exactly once"
    hints = [
        "This mission is about cron field order and exact syntax.",
        "Write the schedule into crontab.txt using the standard five time fields.",
        f"Example: `printf '%s\\n' '{line}' > crontab.txt`",
    ]
    commands = [
        "crontab -l",
        "printf '%s\\n' '15 2 * * * /usr/local/bin/nightly-check' > crontab.txt",
        "cat crontab.txt",
    ]
    return {
        "subtitle": "Schedule Entry",
        "objective": objective,
        "hints": hints,
        "commands": commands,
        "task": {
            "type": "cron_line",
            "output_file": "crontab.txt",
            "expected_line": line,
            "note": "Write the production timer line into crontab.txt.",
        },
    }


BUILDERS = {
    "create_tree_move": build_create_tree_move,
    "extract_match": build_extract_match,
    "count_pattern": build_count_pattern,
    "sort_unique": build_sort_unique,
    "extract_field": build_extract_field,
    "replace_text": build_replace_text,
    "head_tail": build_head_tail,
    "find_and_delete": build_find_and_delete,
    "symlink_target": build_symlink_target,
    "archive_create": build_archive_create,
    "archive_extract": build_archive_extract,
    "chmod_mode": build_chmod_mode,
    "run_script_token": build_run_script_token,
    "loop_generate": build_loop_generate,
    "awk_sum": build_awk_sum,
    "disk_report": build_disk_report,
    "cron_line": build_cron_line,
}


def level_payload(module_name: str, theme: str, focus: str, index: int, total: int) -> dict:
    task_type = PLAN_30[index - 1] if total == 30 else PLAN_24[index - 1]
    difficulty = difficulty_for(index, total, module_name)
    built = BUILDERS[task_type](theme, focus, index)
    mission_name = f"{titleize(focus)}: {built['subtitle']}"
    mission = {
        "name": mission_name,
        "description": mission_description(theme, focus),
        "objective": built["objective"],
        "xp": XP_BY_DIFFICULTY[difficulty],
        "difficulty": difficulty,
        "expected_time": TIME_BY_DIFFICULTY[difficulty],
        "concepts": [titleize(focus), *task_concepts(task_type)],
        "module": module_name,
        "level": f"level-{index}-{slugify(focus)}",
    }
    return {
        "mission": mission,
        "task": built["task"],
        "hints": built["hints"],
        "debrief": debrief_markdown(mission_name, focus, built["commands"], built["hints"]),
    }


def write_level(module_dir: Path, payload: dict, index: int, focus: str) -> None:
    level_dir = module_dir / f"level-{index}-{slugify(focus)}"
    level_dir.mkdir(parents=True, exist_ok=True)
    setup_script, validate_script = shell_wrappers()

    (level_dir / "mission.yaml").write_text(json.dumps(payload["mission"], indent=2) + "\n", encoding="utf-8")
    (level_dir / "level.json").write_text(json.dumps({"task": payload["task"]}, indent=2) + "\n", encoding="utf-8")
    (level_dir / "setup.sh").write_text(setup_script, encoding="utf-8")
    (level_dir / "validate.sh").write_text(validate_script, encoding="utf-8")
    (level_dir / "hint-1.txt").write_text(payload["hints"][0] + "\n", encoding="utf-8")
    (level_dir / "hint-2.txt").write_text(payload["hints"][1] + "\n", encoding="utf-8")
    (level_dir / "hint-3.txt").write_text(payload["hints"][2] + "\n", encoding="utf-8")
    (level_dir / "debrief.md").write_text(payload["debrief"], encoding="utf-8")

    (level_dir / "setup.sh").chmod(0o755)
    (level_dir / "validate.sh").chmod(0o755)


def main() -> None:
    generated_modules = {spec["name"] for spec in MODULE_SPECS}
    for module_name in generated_modules:
        module_dir = MODULES_DIR / module_name
        if module_dir.exists():
            shutil.rmtree(module_dir)

    total_levels = 0
    for spec in MODULE_SPECS:
        module_dir = MODULES_DIR / spec["name"]
        module_dir.mkdir(parents=True, exist_ok=True)
        focuses = spec["focuses"]
        for index, focus in enumerate(focuses, start=1):
            payload = level_payload(spec["name"], spec["theme"], focus, index, len(focuses))
            write_level(module_dir, payload, index, focus)
            total_levels += 1
        print(f"✅ {spec['name']}: {len(focuses)} generated levels")

    print(f"\n✅ Expanded curriculum written: {total_levels} new levels")


if __name__ == "__main__":
    main()
