#!/bin/bash
# Expanded heredoc for bootstrap-time values, \$ for login-time ones, a quoted
# heredoc where nothing may expand, and a marker so a rerun appends nothing.
cat > bootstrap.sh <<'BOOT'
#!/bin/bash
# bootstrap.sh - set up a newcomer's shell.
# Usage:  TEAM=<team> OWNER="<full name>" ./bootstrap.sh     (writes into $HOME)
tools="$(cd "$(dirname "$0")" && pwd)/tools/bin"
mkdir -p "$HOME/.config"

# Fixed at bootstrap time: expand $TEAM and $OWNER now (unquoted delimiter).
cat > "$HOME/.config/team.env" <<EOF
TEAM="$TEAM"
OWNER="$OWNER"
EOF

# Mixed: $tools is expanded now, \$PATH, \$USER and \$HOME stay for login time.
if ! grep -qs '^# >>> team setup >>>$' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<EOF
# >>> team setup >>>
export PATH="$tools:\$PATH"
alias mine='teamctl list --owner "\$USER"'
set -a; . "\$HOME/.config/team.env"; set +a
# <<< team setup <<<
EOF
fi

# Nothing to expand: quoted delimiter, and > so a rerun writes the same file.
cat > "$HOME/.bash_profile" <<'EOF'
# login shells: use the same setup as every other shell
[ -f ~/.bashrc ] && . ~/.bashrc
EOF
BOOT
HOME="$PWD/home" TEAM=payments OWNER="Ana Lima" ./bootstrap.sh
HOME="$PWD/home" TEAM=payments OWNER="Ana Lima" ./bootstrap.sh
tail -6 home/.bashrc
env -i HOME="$PWD/home" PATH=/usr/bin:/bin USER=ana bash -l -i -c 'mine; echo "$PATH"' 2>/dev/null
