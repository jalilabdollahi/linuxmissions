#!/bin/bash
# etc/profile.d with two working scripts and a dead draft (tool.conf); the tool dir exists,
# and a sibling directory with a longer name (bin2) is there to punish substring matching.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc/profile.d opt/tool/bin opt/tool/bin2 .lm-state

printf '#!/bin/sh\necho "tool 3.%s"\n' "$((RANDOM % 9 + 1))" > opt/tool/bin/tool
chmod 755 opt/tool/bin/tool

cat > etc/profile.d/00-editor.sh <<'SH'
# default editor for interactive logins
export EDITOR=vi
export PAGER=less
SH
cat > etc/profile.d/10-locale.sh <<'SH'
# locale for every login shell
if [ -z "$LANG" ]; then
  LANG=C.UTF-8
fi
export LANG
SH
cat > etc/profile.d/tool.conf <<'SH'
# tool: add the vendor binaries (Dana, draft - not working?)
export PATH=$PATH:/opt/tool/bin
SH
cat > README.txt <<'TXT'
Login shells run /etc/profile, which sources the scripts of /etc/profile.d (here etc/profile.d)
for sh and bash alike. In this lab the vendor tool is installed at $SANDBOX/opt/tool/bin.
TXT
