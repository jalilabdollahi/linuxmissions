#!/bin/bash
# Newcomer Bootstrap: bootstrap.sh writes three startup files with heredocs.
# Some values must be expanded when bootstrap runs (TEAM, OWNER, where the
# tools live), others when the newcomer logs in ($PATH, $USER, $HOME). The
# teammate's draft gets both kinds wrong, and appends again on every rerun.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p tools/bin skel

cat > tools/bin/teamctl <<'EOF'
#!/bin/bash
# teamctl - the team's command line tool (stub)
case "$1" in
  list)    echo "teamctl: open tasks for owner '${3:-?}' in team ${TEAM:-?}" ;;
  version) echo "teamctl 0.9.3" ;;
  *)       echo "usage: teamctl list --owner NAME | teamctl version" >&2; exit 2 ;;
esac
EOF
chmod +x tools/bin/teamctl

# What a new account starts with (like /etc/skel on Ubuntu).
cat > skel/.bashrc <<'EOF'
# ~/.bashrc: executed by bash for non-login shells.
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
HISTSIZE=1000
alias ll='ls -alF'
alias la='ls -A'
EOF
cat > skel/.profile <<'EOF'
# ~/.profile: executed by the command interpreter for login shells.
# Not read by bash if ~/.bash_profile or ~/.bash_login exists.
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
EOF
cp -R skel home

cat > bootstrap.sh <<'EOF'
#!/bin/bash
# bootstrap.sh - set up a newcomer's shell (draft, does not work yet).
# Usage:  TEAM=<team> OWNER="<full name>" ./bootstrap.sh     (writes into $HOME)
tools="$(cd "$(dirname "$0")" && pwd)/tools/bin"
mkdir -p "$HOME/.config"

cat > "$HOME/.config/team.env" <<'END'
TEAM=$TEAM
OWNER=$OWNER
END

cat >> "$HOME/.bashrc" <<END
# team setup
export PATH="$tools:$PATH"
alias mine='teamctl list --owner $USER'
set -a; . ~/.config/team.env; set +a
END

cat >> "$HOME/.bash_profile" <<END
. ~/.bashrc
END
EOF
chmod +x bootstrap.sh

cat > ONBOARDING.txt <<'EOF'
Onboarding: shell setup                         (owner: platform team)
-------------------------------------------------------------------------
New accounts start with the files in skel/ (home/ is a copy to try things
on; restore it with: rm -rf home && cp -R skel home). bootstrap.sh is run
once per newcomer, and again whenever onboarding is re-run, with TEAM and
OWNER set, e.g.  HOME=$SANDBOX/home TEAM=payments OWNER="Ana Lima" ./bootstrap.sh

After bootstrap, every new shell of the newcomer (login or not) must:
  - have the team tools first on PATH, followed by the PATH that shell
    started with (the tools directory is this repo's tools/bin, written into
    .bashrc as an absolute path)
  - have TEAM and OWNER exported, with the values given at bootstrap time,
    read from ~/.config/team.env
  - have an alias `mine` that runs  teamctl list --owner "<user>"  where
    <user> is $USER of the shell in which `mine` is used
  - keep everything that was already in ~/.bashrc
Running bootstrap.sh a second time must not change any file.
EOF
