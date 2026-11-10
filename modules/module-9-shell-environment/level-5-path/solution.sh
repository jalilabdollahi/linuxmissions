#!/bin/bash
# Prepend tools/bin with its real absolute path (expanded now, inside double quotes).
echo "export PATH=\"$SANDBOX/tools/bin:\$PATH\"" >> env.sh
tail -2 env.sh
bash -c 'cd / && source "$1" && command -v deploy-helper' _ "$SANDBOX/env.sh"
