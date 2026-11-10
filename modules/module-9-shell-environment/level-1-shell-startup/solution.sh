#!/bin/bash
# Move the export into .bashrc, then make the login file load .bashrc.
grep PROJECT_ROOT home/.profile >> home/.bashrc
grep -v PROJECT_ROOT home/.profile > home/profile.tmp && mv home/profile.tmp home/.profile
echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> home/.bash_profile
env -i HOME="$SANDBOX/home" bash -l -c 'echo "login: $PROJECT_ROOT"'
env -i HOME="$SANDBOX/home" bash -i -c 'echo "tab:   $PROJECT_ROOT"' 2>/dev/null
