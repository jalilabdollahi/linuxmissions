#!/bin/bash
# Run scripts/test_levels.py (and the engine unit tests) inside the
# LinuxMissions container as the non-root user `player`. Arguments go to
# test_levels.py.
#
#   scripts/test-levels-docker.sh                     # every level
#   scripts/test-levels-docker.sh module-4 -v         # one module, verbose
#   scripts/test-levels-docker.sh --unit              # engine unit tests only
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=linuxmissions
docker build -q -t "$IMAGE" docker >/dev/null

if [[ "${1:-}" == "--unit" ]]; then
  exec docker run --rm --init -v "$PWD":/app:ro "$IMAGE" python3 -m unittest discover -s tests -v
fi
exec docker run --rm --init -v "$PWD":/app:ro "$IMAGE" python3 scripts/test_levels.py "$@"
