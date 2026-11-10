#!/bin/bash
# home/.bash_history holds ~45 commands with five secret-bearing lines hidden at random
# positions: a mysql line with -pPASSWORD attached, one with -p 'PASSWORD' (space then
# quote), a mysqldump with --password=, export API_TOKEN=, export DB_PASSWORD=.
# Decoys that must stay: grep -i password, echo/commit messages that mention password,
# `mysql -u root -p` (prompts, no secret), export API_URL, export EDITOR, ...
# home/.bashrc is a typical Ubuntu one with HISTCONTROL=ignoredups already set.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf home .lm-state; mkdir -p home .lm-state
r() { LC_ALL=C tr -dc "$1" < /dev/urandom | head -c "$2"; }

benign=(
  "cd /srv/orders"
  "ls -la"
  "git pull origin main"
  "docker ps"
  "grep -i password /etc/ssh/sshd_config"
  "tail -n 50 /var/log/syslog"
  "mysql -u root -p"
  "cat /etc/passwd | cut -d: -f1"
  "export EDITOR=vim"
  "systemctl status orders-api"
  "echo \"rotate the password on Friday\" >> todo.txt"
  "df -h"
  "export API_URL=https://api.example.com/v2"
  "git commit -m \"remove password from sample config\""
  "vim config/app.yml"
  "ssh-keygen -t ed25519 -C deploy"
  "curl -s \$API_URL/health"
  "free -m"
  "cd ~/reports"
  "python3 export_orders.py --month 2024-03"
  "less orders.csv"
  "wc -l orders.csv"
  "export PATH=\$PATH:~/bin"
  "history | tail"
  "ls -p"
  "grep -rn TODO ."
  "git status"
  "git log --oneline | head"
  "sudo apt list --upgradable"
  "top -bn1 | head -5"
  "cp orders.csv orders.bak"
  "make test"
  "cat notes.txt"
  "man mysql"
  "uptime"
  "ps aux | grep orders"
  "sort -u emails.txt | wc -l"
  "id"
  "exit"
)
secrets=(
  "mysql -uroot -pS3cr3t$(r 'A-Za-z0-9' 8) -h db01 orders"
  "export API_TOKEN=tok_live_$(r 'a-z0-9' 24)"
  "mysql -u root -p '$(r 'A-Za-z0-9' 12)' orders"
  "export DB_PASSWORD=$(r 'A-Za-z0-9' 12)"
  "mysqldump -ureport --password=$(r 'A-Za-z0-9' 10) orders > orders-dump.sql"
)
# insert each secret at a random position of the growing list
all=("${benign[@]}")
for s in "${secrets[@]}"; do
  pos=$((RANDOM % (${#all[@]} - 1)))      # never after the final "exit"
  all=("${all[@]:0:pos}" "$s" "${all[@]:pos}")
done
printf '%s\n' "${all[@]}" > home/.bash_history; chmod 600 home/.bash_history
printf '%s\n' "${benign[@]}" > .lm-state/expected

cat > home/.bashrc <<'RC'
# ~/.bashrc: executed by bash for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# history: don't put duplicate lines in the history
HISTCONTROL=ignoredups
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend

PS1='\u@\h:\w\$ '
alias ll='ls -alF'
alias gs='git status'
RC
cp home/.bashrc .lm-state/bashrc.orig
