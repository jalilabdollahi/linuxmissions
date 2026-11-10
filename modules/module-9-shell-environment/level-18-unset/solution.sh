#!/bin/bash
# Write the reset script, note the readonly variable, then try it.
cat > reset-env.sh <<'EOF'
# reset-env.sh - undo everything legacy-env.sh did to the current shell.
# Usage: source reset-env.sh
unset -v http_proxy https_proxy no_proxy LD_LIBRARY_PATH GREP_OPTIONS CDPATH
unset -f cd
# LEGACY_MODE is readonly: no way to remove it from this shell (see readonly.txt).
EOF
echo LEGACY_MODE > readonly.txt
bash --norc -c 'source ./legacy-env.sh; source ./reset-env.sh; type -t cd; declare -p http_proxy no_proxy LEGACY_MODE'
