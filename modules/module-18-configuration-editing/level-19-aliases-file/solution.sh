#!/bin/bash
export PATH="$PWD/bin:$PATH"   # in the game the sandbox bin/ is first on PATH already
# Rewrite the alias file as a whole: the continuation lines are part of the aliases above them,
# so deleting lines with grep would take recipients (or the alias itself) with it.
cat > etc/aliases <<ALIASES
# /etc/aliases - mail aliases for mail-01
# See aliases(5). Run newaliases after every change.

# Required by RFC 2142
postmaster:    root
mailer-daemon: postmaster
abuse:         postmaster

# cron and system mail goes to a person who left in September
root:          :include:$SANDBOX/etc/oncall.list

dev-team:      alice@corp.example,
               mkhanna@corp.example,
               bob@corp.example
ops:           alice@corp.example
support:       :include:$SANDBOX/etc/oncall.list
security:      secops@corp.example, soc-oncall@corp.example
ALIASES
sed -i '/^mkhan@/Id' etc/oncall.list
newaliases
