#!/bin/bash
# Kim's ~/.bashrc prints a banner and ends with "exec zsh" for every shell,
# including the non-interactive ones scp/rsync/ssh-command start. The host name
# and the banner text change per run. bin/zsh is a stand-in that prints a marker
# so a stray "exec zsh" is visible; the validator needs it in PATH only for
# the non-interactive test.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin home/kim .lm-state

host=$(printf 'bastion-02\nbastion-04\njump-01\njump-03\n' | awk -v s="$RANDOM" 'BEGIN{srand(s)} {a[NR]=$0} END{print a[int(rand()*NR)+1]}')
win=$(printf 'Sun 02:00\nSat 23:30\nTue 04:15\n' | awk -v s="$RANDOM" 'BEGIN{srand(s)} {a[NR]=$0} END{print a[int(rand()*NR)+1]}')

cat > bin/zsh <<'LMEND'
#!/bin/bash
# stand-in for the real zsh: tells you it replaced your shell, then ends
echo "zsh: this shell was replaced by zsh"
exit 0
LMEND
chmod +x bin/zsh

cat > home/kim/.bashrc <<LMEND
# ~/.bashrc: Kim Nowak
export PATH="\$HOME/bin:\$PATH"
export EDITOR=vim
export HISTSIZE=5000

alias ll='ls -alF'
alias gs='git status -sb'
alias k='kubectl'

echo "=== $host | Kim Nowak | maintenance window $win ==="
exec zsh
LMEND
mkdir -p home/kim/bin

{
  echo "HOST=$host"
  echo "WIN='$win'"
} > .lm-state/want
cksum bin/zsh > .lm-state/zsh.sum
