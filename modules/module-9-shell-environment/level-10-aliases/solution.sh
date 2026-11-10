#!/bin/bash
cat > team/aliases.sh <<'EOF'
# team/aliases.sh - shared shell helpers.
# Everyone sources this from ~/.bashrc:   source ~/team/aliases.sh
# LOGDIR is set per host AFTER this file is sourced (see host.env).

alias ll='ls -lah'
alias gs='git status -sb'
alias ..='cd ..'

# show the end of this host's application log ($LOGDIR is read when it runs)
alias logs='tail -n 20 "$LOGDIR/app.log"'

# make a directory and go into it:  mkcd projects/new-thing
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# always ask before deleting
alias rm='rm -i'
EOF
bash -c 'source team/aliases.sh; alias logs rm; type -t mkcd'
