#!/bin/bash
# Command Not Found for Everything. sysroot has /etc/environment, /etc/profile, profile.d/*.sh
# and the homes of deploy and ops. A level-local login-sim copies the login files with /etc and
# /home rewritten into sysroot and runs them in bash's login order (/etc/profile, then the first
# of ~/.bash_profile, ~/.bash_login, ~/.profile) starting from the PATH in /etc/environment
# read literally, as pam_env does. Faults: literal $PATH in /etc/environment, a trailing colon
# and a duplicate in profile.d, a stray ~deploy/.bash_profile shadowing .profile, and a
# duplicate in .profile. The app directory name is random.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin .lm-state sysroot/etc/profile.d sysroot/home/deploy sysroot/home/ops
APPS=(billing ledger mailer scheduler reports)
APP=${APPS[$((RANDOM % 5))]}
BASE=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cat > bin/login-sim <<'MOCKEOF'
#!/bin/bash
# login-sim USER: shows the PATH a login of USER on the captured server in sysroot/ would get.
# It starts from the PATH in etc/environment (read literally, no variable expansion, like
# pam_env), then sources etc/profile (and profile.d through it) and the user's first existing
# file of ~/.bash_profile, ~/.bash_login, ~/.profile, with /etc and /home pointing into sysroot.
# Prints one line: PATH=...   Exit status 1 for an unknown user.
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
[ "$(basename "$HERE")" = bin ] && HERE=$(dirname "$HERE")
S=$HERE/sysroot; U=$1
[ -n "$U" ] && [ -d "$S/home/$U" ] || { echo "usage: login-sim USER (a user with a home in sysroot/home)" >&2; exit 1; }
P=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ -f "$S/etc/environment" ]; then
  L=$(grep -E '^[[:space:]]*(export[[:space:]]+)?PATH=' "$S/etc/environment" | tail -n1 | sed -E 's/^[[:space:]]*(export[[:space:]]+)?PATH=//')
  L=${L%\"}; L=${L#\"}; L=${L%\'}; L=${L#\'}
  [ -n "$L" ] && P=$L
fi
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
cp -a "$S/etc" "$T/etc"; mkdir -p "$T/home"; cp -a "$S/home/$U" "$T/home/$U"
find "$T" -type f -exec sed -i "s#/etc/#$T/etc/#g; s#/home/#$T/home/#g" {} +
env -i HOME="$T/home/$U" USER="$U" LOGNAME="$U" SHELL=/bin/bash PATH="$P" T="$T" \
  /bin/bash --noprofile --norc -c '
    . "$T/etc/profile"
    for f in .bash_profile .bash_login .profile; do
      if [ -r "$HOME/$f" ]; then . "$HOME/$f"; break; fi
    done
    echo "PATH=$PATH"'
MOCKEOF
chmod +x bin/login-sim; ln -sf bin/login-sim login-sim
cat > sysroot/etc/environment <<EOT
PATH="\$PATH:/usr/local/games"
LANG=en_US.UTF-8
EOT
cat > sysroot/etc/profile <<'EOT'
# /etc/profile: system-wide .profile file for the Bourne shell
for i in /etc/profile.d/*.sh; do
  [ -r "$i" ] && . "$i"
done
unset i
export PATH
EOT
cat > sysroot/etc/profile.d/10-app.sh <<EOT
# application tools
PATH=\$PATH:/opt/$APP/bin:
EOT
cat > sysroot/etc/profile.d/90-legacy.sh <<EOT
# added during the 2019 migration
PATH=/opt/$APP/bin:\$PATH
EOT
cat > sysroot/home/deploy/.bash_profile <<'EOT'
# TODO: remove, left from the old box
export PATH=/usr/bin:/bin
EOT
cat > sysroot/home/deploy/.profile <<EOT
# ~/.profile: executed by the command interpreter for login shells.
if [ -n "\$BASH_VERSION" ]; then
    if [ -f "\$HOME/.bashrc" ]; then . "\$HOME/.bashrc"; fi
fi
if [ -d "\$HOME/bin" ] ; then PATH="\$HOME/bin:\$PATH"; fi
export PATH="\$PATH:/opt/$APP/bin"
EOT
cp sysroot/home/deploy/.profile sysroot/home/ops/.profile
sed -i '/\/opt\//d' sysroot/home/ops/.profile
for u in deploy ops; do
cat > sysroot/home/$u/.bashrc <<'EOT'
# ~/.bashrc: executed by bash for non-login shells.
case $- in
    *i*) ;;
      *) return;;
esac
alias ll='ls -alF'
EOT
done
cksum bin/login-sim sysroot/etc/profile > .lm-state/sums
echo "$BASE:/opt/$APP/bin" > .lm-state/want
echo "$APP" > .lm-state/app
