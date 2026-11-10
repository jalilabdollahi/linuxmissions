#!/bin/bash
# Clean Slate: legacy-env.sh pollutes a shell with proxy variables (one of them
# empty), LD_LIBRARY_PATH, GREP_OPTIONS, CDPATH, a cd() wrapper function and a
# readonly LEGACY_MODE. The player writes reset-env.sh, to be sourced, that
# removes everything removable and records the readonly name in readonly.txt.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > legacy-env.sh <<'EOF'
# legacy-env.sh - environment for the 2019 build farm (bf-01..bf-04).
# Usage: source legacy-env.sh
# Do NOT source this on the new runners: it breaks curl, grep, cd and the linker.
export http_proxy=http://proxy.legacy.corp:3128
export https_proxy=$http_proxy
export no_proxy=
export LD_LIBRARY_PATH=/opt/legacy/lib:/opt/oracle/instantclient_11_2
export GREP_OPTIONS='--color=always -i'
CDPATH=.:/opt/legacy/projects
readonly LEGACY_MODE=1
export LEGACY_MODE
cd() {
  builtin cd "$@" && echo "[legacy] now in $PWD"
}
EOF

cat > reset-env.sh <<'EOF'
# reset-env.sh - undo everything legacy-env.sh did to the current shell.
# Usage: source reset-env.sh
# TODO
EOF

cat > NOTE.txt <<'EOF'
From: Mira (CI team)
Somebody sourced legacy-env.sh on runner-07 and now half the jobs act
weird. Opening a new shell is not an option there (it is a long-lived
session). Please write reset-env.sh so we can `source reset-env.sh` in
such a shell and get it back to normal. Anything you cannot remove, write
its name into readonly.txt so we know what is left.
EOF
