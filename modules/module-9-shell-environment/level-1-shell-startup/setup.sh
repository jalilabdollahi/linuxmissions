#!/bin/bash
# Lost on Login: the export sits in ~/.profile, which bash never reads because
# ~/.bash_profile exists, and interactive non-login shells only read ~/.bashrc.
SANDBOX="$1"
mkdir -p "$SANDBOX/home/bin" "$SANDBOX/home/.ssh"
cd "$SANDBOX/home" || exit 1

cat > .bash_profile <<'EOF'
# ~/.bash_profile: personal settings for login shells
export EDITOR=vim
export PATH="$HOME/bin:$PATH"
EOF

cat > .profile <<'EOF'
# ~/.profile: login settings for shells that have no ~/.bash_profile
umask 022

# billing-api checkout used by make and the release scripts (Sam, onboarding day)
export PROJECT_ROOT=/srv/projects/billing-api
EOF

cat > .bashrc <<'EOF'
# ~/.bashrc: interactive shell settings
alias ll='ls -alF'
alias gs='git status -sb'
PS1='\u@\h:\w\$ '
EOF

cat > bin/build-info <<'EOF'
#!/bin/bash
echo "building ${PROJECT_ROOT:?PROJECT_ROOT is not set}"
EOF
chmod +x bin/build-info
