#!/bin/bash
export PATH="$PWD/bin:$PATH"   # the game shell already has bin/ first on PATH
systemctl status legacy-sync
# Who else can start it? report.service wants it.
systemctl list-dependencies --reverse legacy-sync
# Stop it and remove it from the boot ...
systemctl disable --now legacy-sync
# ... and make it impossible to start, even when another unit wants it.
systemctl mask legacy-sync
systemctl status legacy-sync
