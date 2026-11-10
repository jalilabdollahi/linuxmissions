#!/bin/bash
# System-wide login environment on app-04: etc/profile sources etc/profile.d/*.sh
# (POSIX sh, like Debian/Ubuntu). Two snippets already exist, one of which sets
# no_proxy and must survive. The player adds a new snippet with the proxy and
# JAVA_HOME. Traps: a file not ending in .sh is never sourced; [[ ]], arrays or
# `source` break under dash (sh); an echo breaks scp/sftp; plain assignment
# without export is invisible to child processes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc/profile.d .lm-state

cat > etc/profile <<'EOT'
# /etc/profile: system-wide .profile file for the Bourne shell (sh(1))
# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).
# In this sandbox "etc" stands for /etc: LM_ETC (default $SANDBOX/etc) points at it.
: "${LM_ETC:=${SANDBOX:-}/etc}"

if [ "$(id -u)" -eq 0 ]; then
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
else
  PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
fi
export PATH

if [ -d "$LM_ETC/profile.d" ]; then
  for i in "$LM_ETC"/profile.d/*.sh; do
    if [ -r "$i" ]; then
      . "$i"
    fi
  done
  unset i
fi
EOT

cat > etc/profile.d/01-no-proxy.sh <<'EOT'
# internal names and networks that must never go through the proxy
no_proxy=localhost,127.0.0.1,.corp.example,10.0.0.0/8
export no_proxy
EOT
cat > etc/profile.d/02-editor.sh <<'EOT'
# default editor for everybody
EDITOR=vi
export EDITOR
EOT

cat > it-notes.txt <<'EOT'
Ticket IT-2291: login environment on app-04

Every login user (interactive shells and sftp/scp sessions) needs:
  http_proxy   = http://proxy.corp.example:3128
  https_proxy  = http://proxy.corp.example:3128
  JAVA_HOME    = /usr/lib/jvm/java-17-openjdk-amd64
Use the lower-case proxy variable names, export all three, and put them in etc/profile.d/
(do not edit etc/profile). The existing no_proxy list must keep working.
EOT

cksum etc/profile etc/profile.d/01-no-proxy.sh etc/profile.d/02-editor.sh it-notes.txt > .lm-state/inputs
