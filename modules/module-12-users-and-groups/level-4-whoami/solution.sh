#!/bin/bash
# Ask the system who the process runs as instead of reading $USER.
grep -n 'USER' deploy.sh
sed -i 's/\$USER/$(id -un)/g' deploy.sh
grep -n 'id -un' deploy.sh
USER=release ./deploy.sh; echo "exit $?"
