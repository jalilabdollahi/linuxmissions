#!/bin/bash
# Log Discipline: the existing logrotate rule only covers app.log, rotates
# weekly and never compresses, so access.log and worker.log grow forever.
# logrotate.d/ in the sandbox stands for /etc/logrotate.d/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p logrotate.d var/log/myapp

cat > logrotate.d/myapp <<'EOF'
# managed by hand -- see ticket OPS-2291
/var/log/myapp/app.log {
    weekly
    rotate 4
    create 0640 myapp adm
}
EOF

# A snapshot of what /var/log/myapp looks like on the server (sizes in a listing).
cat > var/log/myapp/LISTING.txt <<'EOF'
$ ls -lh /var/log/myapp/
-rw-r----- 1 myapp adm  38M Apr  8 14:30 access.log
-rw-r----- 1 myapp adm 2.1M Apr  8 14:30 app.log
-rw-r----- 1 myapp adm 1.9M Apr  1 00:00 app.log.1
-rw-r----- 1 myapp adm 2.0M Mar 25 00:00 app.log.2
-rw-r----- 1 myapp adm  11G Apr  8 14:30 worker.log
$ # note from the dev team: myapp opens its log files once at startup and
$ # has no signal to reopen them.
EOF
