#!/bin/bash
SANDBOX="$1"
LEVEL_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$LEVEL_DIR/../../../scripts/generated_level_runtime.py" validate "$LEVEL_DIR" "$SANDBOX"
