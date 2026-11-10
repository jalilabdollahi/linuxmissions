#!/bin/bash
# etc/aliases with: root -> mkhan, an alias whose only recipient is mkhan, mkhan in three
# spellings (one capitalised, one as a first recipient on the "name:" line), a colleague called
# mkhanna, an alias continued over indented lines, and an :include: list that holds mkhan too.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p etc bin .lm-state

cat > etc/aliases <<ALIASES
# /etc/aliases - mail aliases for mail-01
# See aliases(5). Run newaliases after every change.

# Required by RFC 2142
postmaster:    root
mailer-daemon: postmaster
abuse:         postmaster

# cron and system mail goes to a person who left in September
root:          mkhan

webmaster:     MKhan@Corp.Example
dev-team:      mkhan@corp.example,
               alice@corp.example,
               mkhanna@corp.example,
               bob@corp.example
ops:           alice@corp.example,
               MKhan@corp.example
backup-admin:  mkhan
support:       :include:$SANDBOX/etc/oncall.list
ALIASES
cat > etc/oncall.list <<'LIST'
# on-call rotation, one address per line
alice@corp.example
Mkhan@corp.example
carol@corp.example
mkhanna@corp.example
LIST
cp etc/aliases .lm-state/aliases.orig
cp etc/oncall.list .lm-state/oncall.orig

cp "$HERE/newaliases.py" bin/newaliases
chmod 755 bin/newaliases
# the database the host built last time (before today's edits)
bin/newaliases 2>/dev/null
touch -d '2 days ago' etc/aliases.db 2>/dev/null || touch -t "$(date -d '2 days ago' +%Y%m%d%H%M 2>/dev/null || date -v-2d +%Y%m%d%H%M)" etc/aliases.db
