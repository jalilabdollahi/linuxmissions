#!/bin/bash
# Take permission bits away instead of setting absolute modes.
cat policy.txt
find app -type f -exec stat -c '%a %n' {} +
find app -path app/bin -prune -o -type f -exec chmod u-x,g-wx,o-rwx {} +
find app/bin -type f -exec chmod g-w,o-rwx {} +
find app -type f -exec stat -c '%a %n' {} +
