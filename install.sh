#!/bin/bash
# LinuxMissions installer
set -euo pipefail
cd "$(dirname "$0")"

echo ""
echo "  LinuxMissions — Installer"
echo "  ─────────────────────────"
echo ""

# ─── Python check ──────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "❌ Python 3 is required."
  echo "   Ubuntu/Debian: sudo apt install python3 python3-venv"
  echo "   macOS:         brew install python3"
  exit 1
fi

PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "✅ Python $PY_VERSION found"

# ─── venv ──────────────────────────────────────────────────────────────────────
if [ ! -d "venv" ]; then
  echo "📦 Creating virtual environment..."
  python3 -m venv venv
fi

echo "📦 Installing Python dependencies..."
venv/bin/pip install --upgrade pip -q
venv/bin/pip install -r requirements.txt -q
echo "✅ Dependencies installed"

# ─── Generate levels.json ──────────────────────────────────────────────────────
echo "⚙️  Generating levels.json..."
venv/bin/python3 scripts/generate_levels.py

# ─── Initial progress.json ─────────────────────────────────────────────────────
if [ ! -f "progress.json" ]; then
  echo '{"player_name":"","total_xp":0,"completed_levels":[],"current_module":"","current_level":"","module_certificates":[],"time_per_level":{},"level_start_time":null}' > progress.json
  echo "✅ progress.json initialized"
fi

# ─── Make scripts executable ───────────────────────────────────────────────────
chmod +x play.sh
find modules -name "*.sh" -exec chmod +x {} \;
echo "✅ Scripts made executable"

echo ""
echo "  ✅ Installation complete!"
echo "  Run: ./play.sh"
echo ""
