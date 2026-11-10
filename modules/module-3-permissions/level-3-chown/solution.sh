#!/bin/bash
# GNU stat uses -c; BSD/macOS stat uses -f with different letters.
if stat -c '%U' / >/dev/null 2>&1; then
  xargs stat -c '%n %U %G' < paths.txt > owners.txt
else
  xargs stat -f '%N %Su %Sg' < paths.txt > owners.txt
fi
xargs -I{} find {} -maxdepth 0 -user "$(whoami)" < paths.txt > fixable.txt
