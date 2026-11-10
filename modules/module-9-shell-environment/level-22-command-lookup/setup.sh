#!/bin/bash
# Which Deploy?: three different things answer to the name `deploy`, depending
# on the kind of shell. Login shells (.bash_profile) put the pinned 1.4 binary
# first on PATH; terminal tabs (.bashrc) define an alias, and the helpers file
# that .bashrc sources defines a function too. Only tools/bin/deploy is current.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
S="$(pwd -P)"
mkdir -p tools/bin opt/deploy-1.4/bin scripts home/.config/team

cat > tools/bin/deploy <<'EOF'
#!/bin/bash
# deploy 2.3.0 - the current deploy tool
echo "deploy 2.3.0 (tools/bin)"
[ "$1" = --version ] && exit 0
echo "deploying ${1:-main} with the 2.x pipeline"
EOF
cat > opt/deploy-1.4/bin/deploy <<'EOF'
#!/bin/bash
# deploy 1.4.2 - kept for rollbacks only (OPS-2201)
echo "deploy 1.4.2 (opt/deploy-1.4) DEPRECATED"
[ "$1" = --version ] && exit 0
echo "deploying ${1:-main} with the 1.x pipeline"
EOF
cat > scripts/deploy-legacy.sh <<'EOF'
#!/bin/bash
# deploy-legacy.sh - the rsync deploy from 2022, before there was a deploy tool
echo "deploy-legacy.sh (rsync) DEPRECATED"
[ "$1" = --version ] && exit 0
echo "rsync -a build/ web-01:/srv/app/"
EOF
chmod +x tools/bin/deploy opt/deploy-1.4/bin/deploy scripts/deploy-legacy.sh

cat > home/.bash_profile <<EOF
# ~/.bash_profile - read by login shells (ssh, the console)
export EDITOR=vi
# OPS-2201: pin deploy 1.4 during the March hotfix (remove after the 2.x rollout)
export PATH="$S/opt/deploy-1.4/bin:\$PATH:$S/tools/bin"
EOF

cat > home/.bashrc <<EOF
# ~/.bashrc - read by interactive non-login shells (new terminal tabs)
case \$- in
  *i*) ;;
  *) return ;;
esac

export PATH="$S/tools/bin:\$PATH"
HISTSIZE=5000

[ -f ~/.config/team/helpers.sh ] && . ~/.config/team/helpers.sh

alias ll='ls -alF'
alias deploy='$S/scripts/deploy-legacy.sh'
EOF

cat > home/.config/team/helpers.sh <<EOF
# helpers.sh - shared team shortcuts, sourced from ~/.bashrc
alias gs='git status -sb'
mkcd() { mkdir -p "\$1" && cd "\$1"; }

# 2024: always deploy with the legacy profile
deploy() {
  "$S/opt/deploy-1.4/bin/deploy" --profile legacy "\$@"
}
EOF

cat > TICKET.txt <<'EOF'
OPS-2290  "deploy" runs a different thing on every terminal
-----------------------------------------------------------
On the jump host (HOME is home/ in this sandbox):
 - SSH sessions (login shells) run deploy 1.4.2, the hotfix pin.
 - New terminal tabs run deploy-legacy.sh, the old rsync script.
 - After `unalias deploy` in a tab, deploy printed 1.4.2 again!?
The 2.x rollout is done. Every new shell, login or not, must run
tools/bin/deploy when someone types `deploy`. Keep opt/deploy-1.4 and
scripts/deploy-legacy.sh on disk for rollbacks, and keep the team's other
shortcuts (ll, gs, mkcd) working.
EOF
