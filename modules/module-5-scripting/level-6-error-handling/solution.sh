#!/bin/bash
# Reference solution: rewrite safe_copy.sh with a heredoc.
cat > safe_copy.sh <<'EOF'
#!/bin/bash
# safe_copy.sh SOURCE_FILE
# Copy a config into deploy/app.conf, without its comment lines.
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "SOURCE_FILE is required" >&2
  exit 1
fi
SOURCE_FILE="$1"

grep -v '^#' "$SOURCE_FILE" | tr -d '\r' > deploy/app.conf
echo "copy complete"
EOF
bash safe_copy.sh "shop settings.conf"
