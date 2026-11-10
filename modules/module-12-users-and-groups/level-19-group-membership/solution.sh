#!/bin/bash
# Skip the header, split each row on commas, and let gpasswd do both files.
# Removing a non-member (or adding an existing member) is simply reported.
tail -n +2 changes.csv | while IFS=, read -r action user group; do
  case "$action" in
    add)    bin/gpasswd -a "$user" "$group" ;;
    remove) bin/gpasswd -d "$user" "$group" ;;
  esac
done
cat etc/group
