#!/bin/bash
# New hires get a broken shell: etc/skel is wrong. The spec says what it should
# contain. alice already has a home that was copied from the broken skel; that
# home must stay as it is. The mock bin/useradd -m copies skel at creation time.
# Traps: skel is read only when the account is created (create dana first and she
# gets the broken copy); `cp skel/*` skips dotfiles; .ssh must be 700 and its
# authorized_keys 600; leftovers (.bash_history, a private key) must go.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc/skel/.ssh etc/default home bin usr/share/base-files .lm .lm-state
M="$(cd "$(dirname "$0")/../../../mocks/accounts" && pwd)"
for t in useradd userdel id; do cp "$M/$t" bin/; done
echo 2026-11-10 > .lm/now

# the package's pristine dotfiles
cat > usr/share/base-files/dot.profile <<'EOT'
# ~/.profile: executed by the command interpreter for login shells.
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
EOT
cat > usr/share/base-files/dot.bashrc <<'EOT'
# ~/.bashrc: executed by bash(1) for non-login shells.
case $- in
    *i*) ;;
      *) return;;
esac
HISTCONTROL=ignoreboth
HISTSIZE=1000
alias ll='ls -alF'
PS1='\u@\h:\w\$ '
EOT
cat > usr/share/base-files/dot.bash_logout <<'EOT'
# ~/.bash_logout: executed by bash(1) when login shell exits.
if [ "$SHLVL" = 1 ]; then
    [ -x /usr/bin/clear_console ] && /usr/bin/clear_console -q
fi
EOT

cat > skel-spec.txt <<'EOT'
# What every new home must start with (mode  path). Directories end in /.
# Files .profile, .bashrc and .bash_logout hold the package's dotfiles (usr/share/base-files/dot.*).
# Nothing else may be in the skeleton.
644  .bash_logout
644  .bashrc
644  .profile
700  .ssh/
600  .ssh/authorized_keys
EOT

# the broken skeleton
cp usr/share/base-files/dot.bash_logout etc/skel/.bash_logout
: > etc/skel/.bashrc                      # empty
echo 'alias rm="rm -rf"  # TODO test' > etc/skel/.bash_history
echo '-----BEGIN OPENSSH PRIVATE KEY----- (devops test key, remove)' > etc/skel/.ssh/id_rsa
: > etc/skel/.ssh/authorized_keys
chmod 777 etc/skel/.bashrc
chmod 644 etc/skel/.bash_logout etc/skel/.bash_history
chmod 644 etc/skel/.ssh/id_rsa etc/skel/.ssh/authorized_keys
chmod 755 etc/skel/.ssh                    # .profile is missing

cat > etc/passwd <<'EOT'
root:x:0:0:root:/root:/bin/bash
alice:x:1000:1000:Alice Moreau:/home/alice:/bin/bash
EOT
cat > etc/group <<'EOT'
root:x:0:
alice:x:1000:
EOT
cat > etc/shadow <<'EOT'
root:!:20000:0:99999:7:::
alice:!:20400:0:99999:7:::
EOT
cat > etc/default/useradd <<'EOT'
GROUP=100
HOME=/home
INACTIVE=-1
EXPIRE=
SHELL=/bin/bash
SKEL=/etc/skel
CREATE_MAIL_SPOOL=no
EOT
cat > etc/login.defs <<'EOT'
UID_MIN 1000
UID_MAX 60000
USERGROUPS_ENAB yes
HOME_MODE 0750
EOT

# alice's home was made from the broken skeleton
mkdir -p home/alice
cp -a etc/skel/. home/alice/
echo "alice's own file" > home/alice/todo.txt

snap() { (cd "$1" && find . | LC_ALL=C sort | while IFS= read -r f; do
  if [ -f "$f" ]; then printf '%s %s %s\n' "$(stat -c %a "$f")" "$f" "$(cksum < "$f")"; else printf '%s %s\n' "$(stat -c %a "$f")" "$f"; fi
done); }
snap home/alice > .lm-state/alice
cksum skel-spec.txt usr/share/base-files/dot.* > .lm-state/inputs
