#!/bin/bash
# agent.conf with a CHANGEME hostname. Decoys: a commented example line
# and another key whose name contains "hostname". The original is kept in
# .lm-state so the validator can prove nothing else changed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
cat > agent.conf <<'T'
# logship agent configuration
# Managed by hand. Restart logship after editing.

[agent]
# hostname = example
hostname = CHANGEME
report_hostname = yes
flush_interval = 15
spool_dir = /var/spool/logship

[output]
# hostname_field overrides the label used in the central index
hostname_field = source_host
server = logs.corp.example:6514
tls = on
T
cp agent.conf .lm-state/agent.conf.orig
cat > TICKET.md <<'T'
# Logs from this box are all labelled CHANGEME

Central logging shows the host as CHANGEME. Set the hostname line in
agent.conf to the name this machine really has (ask the system, not the
sticker on the rack). Don't touch anything else in the file.
T
