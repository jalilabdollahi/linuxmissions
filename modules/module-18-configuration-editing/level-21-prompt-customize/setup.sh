#!/bin/bash
# home/.bashrc with aliases, EDITOR, history settings and a green PS1 whose colour codes are
# not wrapped in \[ \]. The validator will start bash -i from home/work/api with this rc.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p home/work/api .lm-state

hs=$((RANDOM % 5 * 5000 + 5000))
echo "$hs" > .lm-state/histsize
cat > home/.bashrc <<RC
# ~/.bashrc - executed by bash for interactive shells

# nothing to do for non-interactive shells
case \$- in
  *i*) ;;
  *) return ;;
esac

HISTSIZE=$hs
HISTCONTROL=ignoredups
export EDITOR=vim

alias ll='ls -alF'
alias gs='git status -sb'

# prompt (copied from a blog)
PS1='\033[32m\u@\h\033[0m:\w\\\$ '
RC
