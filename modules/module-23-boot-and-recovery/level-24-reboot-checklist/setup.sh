#!/bin/bash
# Pre-Reboot Checklist. The player writes prereboot.sh; the validator runs it on five hidden
# fixture roots built by fixtures.py. Setup only ships two sample roots to test with.
SANDBOX="$1"
LEVEL="$(cd "$(dirname "$0")" && pwd)"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "setup needs python3" >&2; exit 1; }
mkdir -p roots/healthy roots/broken .lm-state
PYTHONPATH="$LEVEL" python3 - <<'PYEOF'
import fixtures
fixtures.build("roots/healthy")
fixtures.build("roots/broken", default="1>2", kernel_missing={"v2"}, fstab="bad", target="dangling", avail=64)
PYEOF
