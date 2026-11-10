#!/bin/bash
# -type d skips the symlink and the files; -perm -0002 ! -perm -1000 means
# world-writable and no sticky bit. Record the list, then fix exactly those.
find srv -type d -perm -0002 ! -perm -1000 | sort | tee fixed.txt
while IFS= read -r d; do chmod +t "$d"; done < fixed.txt
find srv -type d -perm -0002 ! -perm -1000
