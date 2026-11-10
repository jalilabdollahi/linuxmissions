#!/bin/bash
# A contractor is about to get a shell. home/ holds a random mix of exposed secrets
# (readable by others) and hijackable startup files (writable by group/others),
# plus harmless things that must keep their modes: public_html (world-readable on
# purpose), a 644 .vimrc, and a symlink whose own "777" mode means nothing.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf home findings.txt .lm-state; mkdir -p .lm-state home/.ssh home/.aws home/.local/bin home/.config/notify home/public_html

pick() { [ $((RANDOM % 100)) -lt "$1" ]; }          # true with probability $1 %
word() { head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-"$1"; }

# ---- secrets: bad mode when exposed, safe (600 / 700) otherwise ------------------
# name|exposed-mode|content
mkfile() { printf '%s\n' "$3" > "home/$1"; chmod "$2" "home/$1"; }
secret_files=(
  ".netrc|644|machine git.contractor-lab.example login svc-deploy password FAKE-$(word 10)"
  ".pgpass|640|db01.example:5432:orders:report:FAKE-$(word 10)"
  ".my.cnf|664|[client]
user=report
password=FAKE-$(word 10)"
  ".aws/credentials|644|[default]
aws_access_key_id = FAKEKEY$(word 8)
aws_secret_access_key = FAKE$(word 24)"
  ".ssh/id_ed25519|644|-----BEGIN FAKE KEY (training data)-----
$(word 40)
-----END FAKE KEY-----"
)
exposed=()
for i in "${!secret_files[@]}"; do
  IFS='|' read -r name mode content <<< "${secret_files[$i]}"
  content=${secret_files[$i]#*|*|}
  # the first three decide at random, but at least three of five are exposed
  if [ "$i" -lt 3 ] || pick 50; then m=$mode; exposed+=("$name"); else m=600; fi
  mkfile "$name" "$m" "$content"
done
# .ssh itself: exposed (755) or fine (700)
if pick 60; then chmod 755 home/.ssh; else chmod 700 home/.ssh; fi
chmod 700 home/.aws

# ---- startup files and scripts: group/world-writable means hijackable ----------------
mkfile .bashrc 664 $'# ~/.bashrc\nalias ll=\'ls -l\'\nexport EDITOR=vim'
mkfile .profile 644 $'# ~/.profile\n[ -f ~/.bashrc ] && . ~/.bashrc'
mkfile .local/bin/backup.sh 775 $'#!/bin/sh\ntar czf /srv/backup/home.tgz "$HOME/docs"'
chmod 775 home/.local/bin/backup.sh
mkfile .config/notify/hook.sh 755 $'#!/bin/sh\necho "login on $(hostname)" >> "$HOME/.login-log"'
# randomly worsen / soften some of them
pick 50 && chmod 666 home/.bashrc
pick 50 && chmod 644 home/.local/bin/backup.sh
pick 50 && chmod 664 home/.profile

# ---- things that must not change ------------------------------------------------
mkfile .vimrc 644 $'set number\nsyntax on'
mkfile .gitconfig 644 $'[user]\n\tname = Contractor Lab'
mkfile .bash_history 600 $'ls\ncd docs\n'
mkdir -p home/docs; mkfile docs/notes.txt 644 "meeting notes"
printf '<h1>Team page</h1>\n' > home/public_html/index.html; chmod 644 home/public_html/index.html
chmod 755 home/public_html
printf 'body { margin: 0 }\n' > home/public_html/site.css; chmod 644 home/public_html/site.css
printf '%s\n' "$(word 20)" > home/.ssh/id_ed25519.pub; chmod 644 home/.ssh/id_ed25519.pub
printf '%s\n' "ssh-ed25519 AAAAFAKE$(word 20) team" > home/.ssh/authorized_keys; chmod 600 home/.ssh/authorized_keys
ln -s .bashrc home/.zshrc          # a symlink: ls shows lrwxrwxrwx, chmod follows it to .bashrc
ln -s docs/notes.txt home/notes

chmod 755 home/.local home/.local/bin home/.config home/docs
pick 40 && chmod 777 home/.config/notify
# ---- manifest: path|type|expected mode|sha (what the validator compares) ----------
is_secret() { case "$1" in home/.netrc|home/.pgpass|home/.my.cnf|home/.aws/credentials|home/.ssh/id_ed25519|home/.ssh) return 0 ;; esac; return 1; }
: > .lm-state/manifest; : > .lm-state/expected
while IFS= read -r p; do
  if [ -L "$p" ]; then echo "$p|l|-|$(readlink "$p")" >> .lm-state/manifest; continue; fi
  m=$(stat -c %a "$p"); t=f; [ -d "$p" ] && t=d
  want=$m; flag=0
  if is_secret "$p" && [ $((8#$m & 8#077)) -ne 0 ]; then
    want=600; [ "$t" = d ] && want=700; flag=1
  elif [ $((8#$m & 8#022)) -ne 0 ]; then
    want=$(printf '%o' $((8#$m & ~8#022))); flag=1
  fi
  [ "$flag" = 1 ] && echo "$p" >> .lm-state/expected
  sha=-; [ "$t" = f ] && sha=$(sha256sum < "$p" | cut -d' ' -f1)
  echo "$p|$t|$m|$want|$sha|$flag" >> .lm-state/manifest
done < <(find home -mindepth 1 | LC_ALL=C sort)
