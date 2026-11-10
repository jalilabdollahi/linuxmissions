#!/bin/bash
# Read deploy.sh to see the exact sudo commands, then grant exactly those.
cat > sudoers.d/deploy <<'RULE'
# CI deploy user: restart and inspect myapp only
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart myapp.service, /usr/bin/systemctl status myapp.service
RULE
chmod 440 sudoers.d/deploy
visudo -cf sudoers.d/deploy
