#!/bin/bash
# Unprotected Private Key. A home folder whose modes were flattened by a USB
# stick (FAT-style 755/644 or even 777/666). Two private keys, one of them
# named deploy_key (no id_ prefix). Modes are drawn at random on every run.
# Other files under home/ have deliberately odd modes and must stay as they are.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p home/.ssh home/Documents .lm-state

fakekey() {   # fake key material, not a working key
  printf '%s\n' '-----BEGIN OPENSSH PRIVATE KEY-----'
  head -c 270 /dev/urandom | base64 | tr -d '\r'
  printf '%s\n' '-----END OPENSSH PRIVATE KEY-----'
}
fakepub() { echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI$(head -c 24 /dev/urandom | base64 | tr -d '=+/\n') $1"; }
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

fakekey > home/.ssh/id_ed25519
fakekey > home/.ssh/deploy_key
fakepub deploy@build-01 > home/.ssh/id_ed25519.pub
fakepub ci@build-01     > home/.ssh/deploy_key.pub
fakepub alice@laptop    > home/.ssh/authorized_keys
fakepub bob@desktop    >> home/.ssh/authorized_keys
printf 'Host build-01\n  HostName 10.20.0.5\n  User deploy\n  IdentityFile ~/.ssh/deploy_key\n' > home/.ssh/config
printf 'build-01,10.20.0.5 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI%s\n' "$(head -c 24 /dev/urandom | base64 | tr -d '=+/\n')" > home/.ssh/known_hosts

chmod "$(pick 755 775 777)" home/.ssh
chmod "$(pick 644 664 666 755)" home/.ssh/id_ed25519
chmod "$(pick 640 660 777)" home/.ssh/deploy_key
chmod "$(pick 600 640 755)" home/.ssh/id_ed25519.pub
chmod "$(pick 600 664)" home/.ssh/deploy_key.pub
chmod "$(pick 644 666)" home/.ssh/authorized_keys
chmod "$(pick 644 664 755)" home/.ssh/config
chmod "$(pick 666 660)" home/.ssh/known_hosts

# Things outside .ssh that must not be touched (odd modes on purpose).
printf 'export EDITOR=vim\n' > home/.bashrc;        chmod 664 home/.bashrc
printf 'standup notes\n'     > home/Documents/notes.txt; chmod 666 home/Documents/notes.txt
printf '#!/bin/sh\necho build\n' > home/Documents/build.sh; chmod 775 home/Documents/build.sh
chmod 775 home/Documents

mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
( cd home && LC_ALL=C find . -path ./.ssh -prune -o -print | LC_ALL=C sort | while IFS= read -r f; do echo "$(mode "$f") $f"; done ) > .lm-state/rest-modes
( cd home && LC_ALL=C find . -path ./.ssh -prune -o -type f -print | LC_ALL=C sort | xargs cksum ) > .lm-state/rest-sums
( cd home/.ssh && LC_ALL=C find . -type f | LC_ALL=C sort | xargs cksum ) > .lm-state/ssh-sums
