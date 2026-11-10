#!/bin/bash
# file-02: etc/passwd, etc/group, stat.txt (the output of stat -c '%A %U %G %n'
# for six files and the directories above them) and paths.txt. Fixed data with
# the traps built in: kim is in eng only through her primary group (the member
# list does not show it); tomas owns a file whose owner bits are r-- although
# his group has rw-; the group bits of notes.txt are --- while others have rw-;
# directories that others cannot enter hide files that are rw-rw-rw-/rw-rw-r--.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

cat > etc/passwd <<'LMEND'
root:x:0:0:root:/root:/bin/bash
kim:x:1001:2001:Kim Nowak:/home/kim:/bin/bash
tomas:x:1002:1002:Tomas Berg:/home/tomas:/bin/bash
priya:x:1003:1003:Priya Nair:/home/priya:/bin/bash
wen:x:1004:1004:Wen Zhao:/home/wen:/bin/bash
alex:x:1005:1005:Alex Moreau:/home/alex:/bin/bash
LMEND
cat > etc/group <<'LMEND'
root:x:0:
eng:x:2001:tomas,priya
ops:x:2002:tomas,wen,alex
audit:x:2003:wen
tomas:x:1002:
priya:x:1003:
wen:x:1004:
alex:x:1005:
LMEND
cat > stat.txt <<'LMEND'
drwxr-xr-x root root /srv
drwxr-x--- root eng /srv/apollo
-rw-rw-r-- kim eng /srv/apollo/plan.md
-r--rw-r-- tomas eng /srv/apollo/budget.csv
drwxr-xr-x root root /srv/shared
-rw-r----- priya audit /srv/shared/audit.log
-rw----rw- wen ops /srv/shared/notes.txt
-rwxr-x--- alex ops /srv/shared/deploy.sh
drwx------ alex alex /srv/private
-rw-rw-rw- alex alex /srv/private/ssh-keys.txt
LMEND
cat > paths.txt <<'LMEND'
/srv/apollo/plan.md
/srv/apollo/budget.csv
/srv/shared/audit.log
/srv/shared/notes.txt
/srv/shared/deploy.sh
/srv/private/ssh-keys.txt
LMEND
cat > TICKET.md <<'LMEND'
# SEC-640: current access on file-02, before we change anything

For each of kim, tomas, priya, wen, alex and each path in paths.txt, can the
user (a) read the file's contents and (b) modify the file's contents?

Evidence (captured from the server):
  etc/passwd, etc/group    accounts and groups (primary group = 4th passwd field)
  stat.txt                 stat -c '%A %U %G %n' for the six files and for the
                           directories above them

Write matrix.csv:
  user,path,read,write
  <user>,<path>,<yes|no>,<yes|no>      one row per combination, 30 in all
LMEND
cksum etc/passwd etc/group stat.txt paths.txt > .lm-state/inputs
