#!/bin/bash
SANDBOX="$1"

mkdir -p "$SANDBOX/sudoers.d"
touch "$SANDBOX/sudoers.d/devuser"
