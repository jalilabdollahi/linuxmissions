#!/bin/bash
# LinuxMissions launcher
clear
cd "$(dirname "$0")"

# ─── Options ───────────────────────────────────────────────────────────────────
#   --reset    start over from level 1
#   --docker   play inside the LinuxMissions Ubuntu container (recommended on
#              macOS and on Linux hosts missing some tools; needs Docker)
RESET=0
DOCKER=0
for arg in "$@"; do
  case "$arg" in
    --reset) RESET=1 ;;
    --docker) DOCKER=1 ;;
    *) echo "Unknown option: $arg (use --reset and/or --docker)"; exit 1 ;;
  esac
done

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
  exec docker run --rm -it --init --hostname linuxmissions \
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
