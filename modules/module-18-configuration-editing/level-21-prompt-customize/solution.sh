#!/bin/bash
# The old PS1 line goes; a PROMPT_COMMAND function builds PS1 before every prompt. $? must be
# the first thing it reads, because any other command would overwrite it.
sed -i '/^PS1=/d' home/.bashrc
cat >> home/.bashrc <<'RC'
set_prompt() {
  local code=$?
  PS1='\u@\h:\w'
  if [ "$code" -ne 0 ]; then
    PS1+=" \[\e[31m\]$code\[\e[0m\]"
  fi
  PS1+='\$ '
}
PROMPT_COMMAND=set_prompt
RC
tail -9 home/.bashrc
