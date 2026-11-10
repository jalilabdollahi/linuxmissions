#!/bin/bash
# Team Aliases: logs is defined in double quotes (LOGDIR expanded too early),
# mkcd is an alias that tries to use $1, and the rm safety alias is missing.
SANDBOX="$1"
mkdir -p "$SANDBOX/team" "$SANDBOX/var/log/app"
cd "$SANDBOX" || exit 1

cat > team/aliases.sh <<'EOF'
# team/aliases.sh - shared shell helpers.
# Everyone sources this from ~/.bashrc:   source ~/team/aliases.sh
# LOGDIR is set per host AFTER this file is sourced (see host.env).

alias ll='ls -lah'
alias gs='git status -sb'
alias ..='cd ..'

# show the end of this host's application log
alias logs="tail -n 20 $LOGDIR/app.log"

# make a directory and go into it:  mkcd projects/new-thing
alias mkcd='mkdir -p $1 && cd $1'

# TODO: rm must always ask before deleting anything (rm -i)
EOF

cat > host.env <<EOF
# host.env - sourced by ~/.bashrc after team/aliases.sh
export LOGDIR=$SANDBOX/var/log/app
EOF

for i in $(seq 1 60); do
  printf '2026-11-10T09:%02d:%02d %s worker[%d]: job %d finished in %dms\n' $(( i / 2 )) $(( RANDOM % 60 )) \
    INFO $(( RANDOM % 900 + 100 )) $(( RANDOM % 10000 )) $(( RANDOM % 3000 ))
done > var/log/app/app.log
