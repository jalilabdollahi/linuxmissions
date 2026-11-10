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

- **500 levels** across **26 modules** covering core and advanced Linux topics
- **Campaign progression** that starts from module 1 and auto-resumes where you left off
- **Rich terminal UI** with mission briefings, progress panels, and level-complete interstitials
- **Progressive hints** with up to 3 hints per level
- **Post-level debriefs** that explain the concept you just practiced
- **XP and progression tracking** saved locally in `progress.json`
- **In-game Tab autocomplete** for commands and sandbox file names
- **Sandboxed missions** under `/tmp/linuxmissions/...` so practice stays isolated
- **Resettable levels** when you want a clean try
- **Module certificates** when you finish a full module
- **500-level curriculum breakdown**:
  - `158` beginner
  - `174` intermediate
  - `160` advanced
  - `8` expert

---

## Quick Start

```bash
git clone <your-repo-url> linuxmissions
cd linuxmissions
./install.sh
./play.sh
```

To reset progress and start over from level 1:

```bash
./play.sh --reset
```

---

## Prerequisites

| Tool | Install |
|------|---------|
| Python `3.9+` | Ubuntu/Debian: `sudo apt install python3 python3-venv` |
| bash | Preinstalled on most Linux/macOS systems |

`install.sh` will:

- create a local virtual environment
- install Python dependencies from `requirements.txt`
- generate `levels.json`
- initialize `progress.json` if needed

---

## How To Play

1. Run `./play.sh`
2. Read the mission briefing and objective
3. Inspect the sandbox shown on screen
4. Use normal shell commands to solve the task
5. Let the game auto-validate after each command
6. Read the debrief, press Enter, and continue to the next level

Every mission runs in a sandbox like:

```bash
/tmp/linuxmissions/module-1-filesystem/level-2-create-dirs
```

That means you can safely experiment without touching the project repo itself.

---

## Gameplay Commands

These are available directly inside the game:

| Command | Description |
|---------|-------------|
| `hint` | Reveal the next hint. Each hint lowers the XP for the level (90%, 75%, 50%) |
| `hints` | Show the hints you already revealed |
| `validate` | Check your work and see what is still missing |
| `edit <file>` | Open a file in a real editor (`$EDITOR`, else nano or vim); `nano`, `vim`, `less`, `man`, `top` also work directly |
| `help` | Show the full command list |
| `status` | Show progress and XP |
| `objective` | Re-display the current objective |
| `reset` | Rebuild the current level sandbox |
| `skip` | Skip the current level with no XP |
| `quit` / `exit` | Save progress and leave the game |
| `Tab` | Autocomplete commands and sandbox file names |
| `Ctrl-C` | Stop a running command such as `tail -f` or `sleep` |
| `<any shell cmd>` | Run a real command inside the current sandbox |

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

LinuxMissions now includes **26 modules**:

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
| 9 | Shell Environment | 24 | shell behavior, redirection, globbing, environment |
| 10 | Archives & Compression | 24 | tarballs, extraction, backups, compression workflows |
| 11 | Find & Pipelines | 24 | `find`, `grep`, `cut`, `awk`, pipeline composition |
| 12 | Users & Groups | 24 | identity, ownership, account layout, access review |
| 13 | Services & Logs | 24 | service inspection, journal reading, log triage |
| 14 | Storage & Backups | 24 | mounts, backups, restore drills, data layout |
| 15 | Scheduling & Jobs | 24 | cron, timers, background jobs, recurring automation |
| 16 | Security Auditing | 24 | permission hardening, secrets hygiene, audit tasks |
| 17 | Monitoring & Performance | 24 | process inspection, resource hotspots, system health |
| 18 | Configuration Editing | 24 | config cleanup, text edits, review and rewrite flows |
| 19 | Network Troubleshooting | 24 | routing, DNS, HTTP checks, connectivity analysis |
| 20 | Package & Release Ops | 24 | package inspection, versions, release handling |
| 21 | Shell Automation | 24 | reusable shell scripts, loops, traps, safety flags |
| 22 | Data Processing | 24 | reports, CSV handling, summaries, transformations |
| 23 | Boot & Recovery | 24 | recovery notes, boot failures, restore workflows |
| 24 | System Inspection | 24 | kernel, OS, hardware, process and system inventory |
| 25 | Linux Toolbelt | 24 | small but powerful Unix tools for daily ops |
| 26 | Linux War Games | 30 | multi-step incident scenarios and integrated drills |

---

## Difficulty Breakdown

From the current registry in `levels.json`:

| Difficulty | Levels |
|------------|--------|
| Beginner | 158 |
| Intermediate | 174 |
| Advanced | 160 |
| Expert | 8 |

This gives the project a broad slope from first-day Linux commands to longer, multi-step troubleshooting missions.

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
├── engine/
│   ├── engine.py
│   ├── ui.py
│   ├── player.py
│   ├── reset.py
│   ├── safety.py
│   └── certificate.py
├── scripts/
│   ├── generate_levels.py
│   ├── generate_expanded_curriculum.py
│   └── generated_level_runtime.py
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
├── hint-1.txt
├── hint-2.txt
├── hint-3.txt
└── debrief.md
```

Some generated levels also include a `level.json` file used by the shared setup/validation runtime.

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
- module certificates
- time per level

The game auto-saves as you play.

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
