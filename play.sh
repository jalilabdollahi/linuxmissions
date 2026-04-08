#!/bin/bash
# LinuxMissions launcher
clear
cd "$(dirname "$0")"

# ─── Reset option ──────────────────────────────────────────────────────────────
if [[ "$1" == "--reset" ]]; then
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
