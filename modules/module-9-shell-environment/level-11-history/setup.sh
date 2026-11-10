#!/bin/bash
# Who Deleted the Uploads: a timestamped .bash_history over three nights.
# The obvious rm -rf is at 01:58 (outside the window); the real deletion is a
# find ... -delete on $D, which was pointed at the uploads three commands
# earlier. The same find ran harmlessly the night before (on the cache).
SANDBOX="$1"
mkdir -p "$SANDBOX/home/deploy"
cd "$SANDBOX" || exit 1

BASE=1790812800                       # 2026-10-01 00:00:00 UTC
day=$(( 5 + RANDOM % 40 ))            # incident day: 2026-10-06 .. 2026-11-14
T0=$(( BASE + day * 86400 ))          # incident day 00:00 UTC
Y0=$(( T0 - 86400 ))                  # the night before
P0=$(( T0 - 2 * 86400 ))

utc() { date -u -d "@$1" "$2" 2>/dev/null || date -u -r "$1" "$2"; }

h() { printf '#%d\n%s\n' "$1" "$2"; }   # h EPOCH COMMAND
s() { echo $(( RANDOM % 60 )); }
cmin=$(( 11 + RANDOM % 9 ))           # culprit at 02:11 .. 02:19

{
  h $(( P0 + 9*3600 + 14*60 + $(s) )) 'cd /srv/app'
  h $(( P0 + 9*3600 + 15*60 + $(s) )) 'git -C /srv/app log --oneline -5'
  h $(( P0 + 9*3600 + 21*60 + $(s) )) 'sudo systemctl status app'
  h $(( P0 + 16*3600 + 2*60 + $(s) ))  'df -h /srv'

  h $(( Y0 + 1*3600 + 55*60 + $(s) )) 'cd /srv/app'
  h $(( Y0 + 2*3600 + 12*60 + $(s) )) 'D=/srv/app/cache'
  h $(( Y0 + 2*3600 + 13*60 + $(s) )) 'du -sh $D'
  h $(( Y0 + 2*3600 + 16*60 + $(s) )) 'find $D -type f -mmin +5 -delete'
  h $(( Y0 + 2*3600 + 17*60 + $(s) )) 'du -sh $D'
  h $(( Y0 + 2*3600 + 30*60 + $(s) )) 'exit'

  h $(( T0 + 1*3600 + 49*60 + $(s) )) 'cd /srv/app'
  h $(( T0 + 1*3600 + 51*60 + $(s) )) 'tail -n 100 /var/log/app/error.log'
  h $(( T0 + 1*3600 + 58*60 + $(s) )) 'rm -rf /srv/app/tmp/*'
  h $(( T0 + 2*3600 + 3*60 + $(s) ))  'D=/srv/app/shared/uploads'
  h $(( T0 + 2*3600 + 5*60 + $(s) ))  'ls $D | wc -l'
  h $(( T0 + 2*3600 + 8*60 + $(s) ))  'du -sh $D'
  h $(( T0 + 2*3600 + cmin*60 + $(s) )) 'find $D -type f -mmin +5 -delete'
  h $(( T0 + 2*3600 + 21*60 + $(s) )) 'ls $D | wc -l'
  h $(( T0 + 2*3600 + 22*60 + $(s) )) 'sudo systemctl restart app'
  h $(( T0 + 2*3600 + 24*60 + $(s) )) 'exit'

  h $(( T0 + 8*3600 + 40*60 + $(s) )) 'cd /srv/app/shared'
  h $(( T0 + 8*3600 + 41*60 + $(s) )) 'ls -la uploads'
} > home/deploy/.bash_history

cat > home/deploy/.bashrc <<'EOF'
# ~/.bashrc for deploy@bastion
HISTCONTROL=ignoreboth
HISTSIZE=500
HISTFILESIZE=1000

alias ll='ls -alF'
PS1='\u@bastion:\w\$ '
EOF

cat > INCIDENT.txt <<EOF
INC-5521  Customer uploads missing on bastion-01
Date:   $(utc "$T0" +%F)
Window: 02:10 - 02:25 UTC (uploads were fine at 02:10, gone at 02:25)
Only user logged in during the night: deploy
History file: home/deploy/.bash_history (one "#<seconds since 1970>" line before each command)
EOF
