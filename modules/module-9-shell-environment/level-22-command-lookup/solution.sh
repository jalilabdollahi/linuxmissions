#!/bin/bash
# See what each kind of shell thinks deploy is.
env -i HOME="$PWD/home" PATH=/usr/bin:/bin bash -l -i -c 'type -a deploy' 2>/dev/null
env -i HOME="$PWD/home" PATH=/usr/bin:/bin bash -i -c 'type -a deploy' 2>/dev/null

# 1. login shells: drop the 1.4 pin, and read .bashrc like every other shell.
sed -i.bak '/deploy-1.4/d' home/.bash_profile
echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> home/.bash_profile
# 2. terminal tabs: remove the alias ...
sed -i.bak '/^alias deploy=/d' home/.bashrc
# 3. ... and the function that hides behind it (deploy() { ... } is three lines).
sed -i.bak '/^deploy() {$/,/^}$/d' home/.config/team/helpers.sh
rm -f home/.bash_profile.bak home/.bashrc.bak home/.config/team/helpers.sh.bak

env -i HOME="$PWD/home" PATH=/usr/bin:/bin bash -l -i -c 'type -a deploy' 2>/dev/null
env -i HOME="$PWD/home" PATH=/usr/bin:/bin bash -i -c 'type -t ll mkcd; deploy --version' 2>/dev/null
