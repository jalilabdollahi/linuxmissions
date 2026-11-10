#!/bin/bash
# Folder private, secrets 600, public things readable.
ls -la home/.ssh
chmod 700 home/.ssh
chmod 600 home/.ssh/id_ed25519 home/.ssh/deploy_key home/.ssh/authorized_keys home/.ssh/config
chmod 644 home/.ssh/*.pub home/.ssh/known_hosts
ls -la home/.ssh
