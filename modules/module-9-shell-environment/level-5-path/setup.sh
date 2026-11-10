#!/bin/bash
# Stale Helper: env.sh puts legacy/bin on PATH, so its old deploy-helper wins.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p legacy/bin tools/bin

cat > legacy/bin/deploy-helper <<'EOF'
#!/bin/sh
echo "deploy-helper 1.4.2 (legacy): uploading with rsync over ssh ..."
echo "WARNING: this build talks to the old artifact store" >&2
EOF
cat > legacy/bin/report-legacy <<'EOF'
#!/bin/sh
echo "report-legacy 0.9: weekly deploy report"
EOF
cat > tools/bin/deploy-helper <<'EOF'
#!/bin/sh
echo "deploy-helper 2.3.0: uploading to the artifact store ..."
EOF
cat > tools/bin/release-notes <<'EOF'
#!/bin/sh
echo "release-notes 2.3.0"
EOF
chmod +x legacy/bin/* tools/bin/*

{
  echo '# env.sh - team environment. Login shells and CI run:  source /path/to/env.sh'
  echo 'export LANG=C.UTF-8'
  echo 'export DEPLOY_TARGET=staging'
  echo '# old toolchain, still needed for report-legacy'
  printf 'export PATH="%s/legacy/bin:$PATH"\n' "$SANDBOX"
} > env.sh
