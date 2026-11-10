# LinuxMissions

![platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-blue)
![shell](https://img.shields.io/badge/shell-bash-brightgreen)
![python](https://img.shields.io/badge/python-3.9%2B-3776ab)

> **Learn Linux by fixing real terminal problems, one mission at a time.**

LinuxMissions is a fully local, game-based Linux training platform with a rich terminal interface. Each level drops you into a sandbox with something broken, incomplete, or messy. Your job is to inspect it, fix it, and validate your solution using real shell commands.

**500 progressive challenges across 26 modules — from basic navigation to Linux war games.**  
No cloud bill. No VM farm. No disposable lab account.

**Design and implementation by: Jalil Abdollahi**  
Email: `jalil.abdollahi@gmail.com`

---


## Features

- **500 hand-written levels** across **26 modules**, each a realistic scenario with its own data, traps and checks
- **Every level is tested**: setup works, a fresh sandbox does not pass, and a reference solution does
- **Campaign progression** that starts from module 1 and auto-resumes where you left off
- **Terminal UI** with a progress header, mission cards, clear pass/fail feedback and a debrief after every level
- **Progressive hints**, up to 3 per level; each one lowers the level's XP
- **XP and ranks** (Recruit → Operator → Sysadmin → Engineer → Root), saved locally in `progress.json`
- **One-key shortcuts** (`h` hint, `v` validate, `s` status, `?` help) and Tab completion
- **Docker play mode** with every tool the levels need, recommended on macOS
- **Realistic stand-ins** for systemd, apt/dpkg, cron, user accounts, sshd and network services, so levels that would need root or the internet run as a normal user, offline
- **Resettable levels** and **module certificates**

---

## Quick Start

```bash
git clone https://github.com/jalilabdollahi/linuxmissions.git
cd linuxmissions
./play.sh --docker
```

`--docker` plays inside the LinuxMissions Ubuntu container, which has every tool
the levels use; your progress is still saved in this folder. It is the
recommended way to play on macOS, and on any Linux machine that lacks some of
those tools. Many levels rely on Linux-only behaviour (`/proc`, apt/dpkg, GNU
tools, Linux file modes).

To play directly on a Linux host instead:

```bash
./install.sh
./play.sh
```

In Docker mode the sandboxes live inside the container, not in `/tmp/linuxmissions`
on your Mac: the levels need Linux's own filesystem (case-sensitive names, ACLs,
FIFOs, Linux file modes), which a folder shared from macOS does not provide. To
look around, edit files or test in a second terminal tab while the game runs:

```bash
./play.sh --shell
```

It opens a shell in the same container, already in the current level's sandbox
(`$SANDBOX` is set and `$SANDBOX/bin` is first on `PATH`, as in the game).

To reset progress and start over from level 1:

```bash
./play.sh --reset
```

---

## Prerequisites

| Tool | Install |
|------|---------|
| Docker | For `./play.sh --docker` (recommended): Docker Desktop on macOS, `docker.io` on Linux |
| Python `3.9+` | Only to play without Docker. Ubuntu/Debian: `sudo apt install python3 python3-venv` |
| bash | Preinstalled on most Linux/macOS systems |

Without Docker, `install.sh` will:

- create a local virtual environment
- install Python dependencies from `requirements.txt`
- generate `levels.json`
- initialize `progress.json` if needed

---

## How To Play

1. Run `./play.sh --docker` (or `./play.sh` on a Linux host)
2. Read the mission and its objective
3. Inspect the sandbox shown on screen
4. Use normal shell commands to solve the task
5. The game checks your work after every command; type `validate` (or `v`) to see what is still missing
6. Read the debrief, press Enter, and continue to the next level

Every mission runs in a sandbox like:

```bash
/tmp/linuxmissions/module-1-filesystem/level-2-create-dirs
```

That means you can safely experiment without touching the project repo itself.

---

## Gameplay Commands

These are available directly inside the game:

| Command | Shortcut | Description |
|---------|----------|-------------|
| `hint` | `h`, F2 | Reveal the next hint. Each hint lowers the XP for the level (90%, 75%, 50%) |
| `hints` | | Show the hints you already revealed |
| `validate` | `v`, F3 | Check your work and see what is still missing |
| `objective` | `o`, F4 | Show the mission again |
| `status` | `s`, F5 | XP, rank and progress in every module |
| `help` | `?`, F1 | Show every command and shortcut |
| `edit <file>` | | Open a file in a real editor (`$EDITOR`, else nano or vim); `nano`, `vim`, `less`, `man`, `top` also work directly |
| `reset` | | Rebuild the current level sandbox |
| `skip` | | Skip the current level with no XP |
| `quit` / `exit` | `q` | Save progress and leave the game |
| `Tab` | | Complete commands and sandbox file names (on an empty line: the game's commands) |
| `Ctrl-C` | | Stop a running command such as `tail -f` or `sleep` |
| `<any shell cmd>` | | Run a real command inside the current sandbox |

Shortcuts are typed alone, then Enter. Function keys act at once where the
terminal sends them (on a Mac keyboard: `fn` + F2).

Multi-line input works: heredocs (`cat > script.sh <<'EOF'`), `if`/`for`/`while`
blocks and lines ending in `|` or `\` continue on a `...>` prompt.

Examples:

```bash
ls -la
cat README
grep ERROR app.log > alerts.txt
find . -name '*.tmp' -delete
tar -xzf backup.tar.gz
```

---

## Learning Path

LinuxMissions has **26 modules**. Modules 1–8 are short introductions; modules
9–26 go deep, and module 26 combines everything in multi-cause incidents. The
level-by-level plan for modules 9–26 is in [docs/curriculum/](docs/curriculum/).

| # | Module | Levels | Focus |
|---|--------|--------|-------|
| 1 | Filesystem | 10 | navigation, directories, copy/move, archives, links |
| 2 | Text Processing | 8 | `head`, `tail`, `grep`, `wc`, `sort`, `sed` |
| 3 | Permissions | 8 | `chmod`, `chown`, file modes, access control basics |
| 4 | Processes | 6 | `ps`, `kill`, jobs, nice, signals, zombies |
| 5 | Scripting | 8 | variables, conditionals, loops, functions, heredocs |
| 6 | Networking | 8 | `ip`, `ping`, DNS, ports, `curl` |
| 7 | Sysadmin | 8 | services, logs, users, disk usage, environment |
| 8 | Advanced Text | 6 | deeper `awk`, `sed`, joins, pipelines |
| 9 | Shell Environment | 24 | how bash parses a line (quoting, globbing, expansion, redirection), variables, PATH, aliases, startup files |
| 10 | Archives & Compression | 24 | tar member selection, gzip/bzip2/xz/zip/cpio, splitting large files, checksums, sizing restores |
| 11 | Find & Pipelines | 24 | `find` predicates and actions, grep options, cut/paste/join/comm/sort/uniq/tr, multi-stage pipelines |
| 12 | Users & Groups | 24 | passwd/shadow/group, login.defs, skel, sudoers, password aging and locks, shared directories, subuid |
| 13 | Services & Logs | 24 | systemd units, enable vs start, reload vs restart, drop-ins, restart policy, journal and kernel logs |
| 14 | Storage & Backups | 24 | partitioning and formatting disk images, fstab, rsync and snapshots, retention, verifying restores |
| 15 | Scheduling & Jobs | 24 | cron and its traps, at/batch, systemd timers, job control, detaching, locks, logrotate |
| 16 | Security Auditing | 24 | permission hardening, SSH server and key hygiene, signatures, leaked secrets, SUID, sudo review |
| 17 | Monitoring & Performance | 24 | top/free/vmstat, targeting processes, nice/ionice, open files and sockets, disk and memory hotspots |
| 18 | Configuration Editing | 24 | hidden characters, in-place edits, sections and columns, diffs and patches, templates, config checks |
| 19 | Network Troubleshooting | 24 | interfaces and routes, ping/traceroute/MTU, DNS with dig, HTTP and TLS checks, ports, outages |
| 20 | Package & Release Ops | 24 | apt and dpkg in depth, pins and holds, repositories and keys, versions, release manifests, rollbacks |
| 21 | Shell Automation | 24 | unattended bash: arguments, exit codes, loops over real input, traps, `set -euo pipefail`, reuse |
| 22 | Data Processing | 24 | messy CSV, fixed-width and log exports turned into correct reports with awk, sort and join |
| 23 | Boot & Recovery | 24 | repairing a server that won't boot from its captured disk: GRUB, initramfs, fstab, units, libraries |
| 24 | System Inspection | 24 | uname, /proc and /sys, login records, sockets, kernel parameters, limits, cgroups and namespaces |
| 25 | Linux Toolbelt | 24 | tee, xargs -0, printf, seq, fmt, expand, csplit, od/xxd, base64, time, script, driving prompts |
| 26 | Linux War Games | 30 | on-call incidents with several causes and decoys, combining skills from every earlier module |

---

## Difficulty Breakdown

From the current registry in `levels.json`:

| Difficulty | Levels |
|------------|--------|
| Beginner | 115 |
| Intermediate | 167 |
| Advanced | 160 |
| Expert | 58 |

A level is worth 100 (beginner), 150 (intermediate), 200 (advanced) or 300
(expert) XP, 85,950 XP in total. Ranks by total XP:

| Rank | From |
|------|------|
| Recruit | 0 |
| Operator | 1,000 |
| Sysadmin | 5,000 |
| Engineer | 15,000 |
| Root | 30,000 |

---

## Project Structure

```text
linuxmissions/
├── README.md
├── SPEC.md
├── play.sh
├── install.sh
├── requirements.txt
├── progress.json
├── levels.json
├── docker/            # the Ubuntu image used by --docker and the tests
├── docs/
│   ├── LEVEL_AUTHORING.md
│   └── curriculum/    # level-by-level plan for modules 9-26
├── engine/
│   ├── engine.py      # game loop, shell session, input
│   ├── ui.py          # screens (Rich)
│   ├── runner.py      # runs setup.sh / validate.sh / solution.sh
│   ├── player.py
│   ├── reset.py
│   ├── safety.py
│   └── certificate.py
├── mocks/             # shared stand-ins: systemd, apt/dpkg, cron, accounts, sshd, network servers
├── tests/             # engine and mock unit tests
├── scripts/
│   ├── generate_levels.py
│   ├── test_levels.py
│   ├── test-levels-docker.sh
│   └── check_duplicates.py
└── modules/
    ├── module-1-filesystem/
    ├── module-2-text/
    ├── ...
    └── module-26-linux-wargames/
```

Each level directory contains:

```text
level-N-name/
├── mission.yaml
├── setup.sh
├── validate.sh
├── solution.sh
├── hint-1.txt
├── hint-2.txt
├── hint-3.txt
└── debrief.md
```

Every level is written by hand for its topic; see `docs/LEVEL_AUTHORING.md`. Shared
stand-ins for tools that need root, a daemon or the network live in `mocks/`.

---

## Progress And Saves

Progress is stored locally in:

```bash
progress.json
```

That file tracks:

- player name
- total XP
- completed levels
- current module and current level
- hints revealed per level
- module certificates
- time per level

The game auto-saves as you play. Progress is keyed by level folder name, so
levels that were renamed in the 2026 rewrite (some in modules 9–26) start fresh.

---

## Writing And Testing Levels

How to write a level (file contract, validator rules, hint standard):
[docs/LEVEL_AUTHORING.md](docs/LEVEL_AUTHORING.md).

Every level ships a reference `solution.sh`. The test runner checks that each
level sets up cleanly, does **not** pass before any work is done, and **does**
pass after its solution:

```bash
scripts/test-levels-docker.sh                 # all levels, Ubuntu container, non-root
scripts/test-levels-docker.sh module-4 -v     # one module, verbose
scripts/test-levels-docker.sh --unit          # engine unit tests
python3 scripts/generate_levels.py            # rebuild levels.json after adding levels
```

---

## Why This Project Exists

LinuxMissions is designed to make Linux practice feel active instead of passive. Instead of just reading command references, you solve focused tasks in a safe sandbox, get feedback immediately, and build muscle memory through repetition.

It works well for:

- beginners learning the shell
- developers who want stronger Linux fluency
- DevOps and SRE learners building troubleshooting habits
- interview prep for practical Linux command work

---

## Contributing

If you want to improve the game:

- add handcrafted levels
- improve validators and debriefs
- tighten the UI and mission flow

Start with [docs/LEVEL_AUTHORING.md](docs/LEVEL_AUTHORING.md), then inspect `modules/`, `engine/`, and `scripts/`.

---

## License

Add your preferred license file here if you plan to publish the project.
