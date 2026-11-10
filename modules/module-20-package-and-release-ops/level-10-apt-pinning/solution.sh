#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
apt-cache policy | grep -B1 -A1 backports
cat > rootfs/etc/apt/preferences.d/ripgrep.pref <<'PREF'
Package: ripgrep
Pin: release a=noble-backports
Pin-Priority: 600
PREF
apt-cache policy ripgrep fd-find
