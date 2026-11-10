#!/bin/bash
# LinuxMissions launcher
clear
cd "$(dirname "$0")"

# ─── Options ───────────────────────────────────────────────────────────────────
#   --reset    start over from level 1
#   --docker   play inside the LinuxMissions Ubuntu container (recommended on
#              macOS and on Linux hosts missing some tools; needs Docker)
#   --shell    while a --docker game is running: open a second shell inside
#              the same container, in the current level's sandbox
#              (/tmp/linuxmissions/<module>/<level>), e.g. in another terminal tab
RESET=0
DOCKER=0
SHELL_IN=0
for arg in "$@"; do
  case "$arg" in
    --reset) RESET=1 ;;
    --docker) DOCKER=1 ;;
    --shell) SHELL_IN=1 ;;
    *) echo "Unknown option: $arg (use --reset, --docker or --shell)"; exit 1 ;;
  esac
done

CONTAINER=linuxmissions-game

# ─── Shell in the running container ────────────────────────────────────────────
# The sandbox lives inside the container (on Linux's own filesystem: the levels
# rely on case-sensitive names, ACLs, FIFOs and Linux modes that a macOS folder
# shared into Docker does not provide), so it is opened from here instead.
if [[ "$SHELL_IN" == 1 ]]; then
  if [ -z "$(docker ps -q -f "name=^${CONTAINER}$" 2>/dev/null)" ]; then
    echo "❌ No game is running in Docker. Start one first with: ./play.sh --docker"
    exit 1
  fi
  DOCKER_CLI_HINTS=false exec docker exec -it -u player -e HOME=/home/player -e TERM="${TERM:-xterm-256color}" \
    -w /app "$CONTAINER" bash -c '
      sb=$(python3 -c "import json; d = json.load(open(\"progress.json\")); print(\"/tmp/linuxmissions/\" + d[\"current_module\"] + \"/\" + d[\"current_level\"])" 2>/dev/null)
      [ -n "$sb" ] && [ -d "$sb" ] || sb=/tmp/linuxmissions
      export SANDBOX="$sb" PATH="$sb/bin:$PATH"
      cd "$sb" || exit 1
      echo "📂 Sandbox: $sb   (Ctrl-D or exit to close this shell; the game keeps running)"
      exec bash -i'
fi

# ─── Reset option ──────────────────────────────────────────────────────────────
if [[ "$RESET" == 1 ]]; then
  if [ ! -f "progress.json" ]; then
    echo "ℹ️  No progress file found — nothing to reset."
    exit 0
  fi
  read -r -p "⚠️  Reset all progress? This cannot be undone. [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    PLAYER=$(python3 -c "import json; d=json.load(open('progress.json')); print(d.get('player_name',''))" 2>/dev/null || echo "")
    echo "{\"player_name\":\"$PLAYER\",\"total_xp\":0,\"completed_levels\":[],\"current_module\":\"\",\"current_level\":\"\",\"module_certificates\":[],\"time_per_level\":{},\"level_start_time\":null}" > progress.json
    echo "✅ Progress reset. Starting from Module 1 Level 1."
  else
    echo "Cancelled."
    exit 0
  fi
fi

# ─── Docker mode ───────────────────────────────────────────────────────────────
if [[ "$DOCKER" == 1 ]]; then
  if ! command -v docker &>/dev/null; then
    echo "❌ Docker is not installed. Install Docker Desktop (macOS) or docker.io (Linux)."
    exit 1
  fi
  echo "⚙️  Preparing the LinuxMissions container (first run takes a few minutes)..."
  docker build -q -t linuxmissions docker >/dev/null || { echo "❌ docker build failed"; exit 1; }
  if [ -n "$(docker ps -q -f "name=^${CONTAINER}$")" ]; then
    echo "❌ A LinuxMissions game is already running in Docker. Use ./play.sh --shell for a second terminal."
    exit 1
  fi
  exec docker run --rm -it --init --name "$CONTAINER" --hostname linuxmissions \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    -v "$(pwd)":/app linuxmissions \
    bash -c '[ -f levels.json ] || python3 scripts/generate_levels.py >/dev/null; exec python3 -m engine.engine'
fi

# ─── venv guard ────────────────────────────────────────────────────────────────
if [ ! -d "venv" ]; then
  echo "❌ Virtual environment not found. Run ./install.sh first."
  exit 1
fi

# ─── levels.json guard ─────────────────────────────────────────────────────────
if [ ! -f "levels.json" ]; then
  echo "⚙️  levels.json not found — generating..."
  venv/bin/python3 scripts/generate_levels.py || { echo "❌ Failed to generate levels.json"; exit 1; }
fi

# ─── Launch ────────────────────────────────────────────────────────────────────
export PYTHONPATH="$(pwd):$PYTHONPATH"

if [ -f "venv/bin/python3" ]; then
  venv/bin/python3 -m engine.engine
elif [ -f "venv/Scripts/python.exe" ]; then
  venv/Scripts/python.exe -m engine.engine
else
  echo "❌ Python interpreter not found inside venv"
  exit 1
fi
