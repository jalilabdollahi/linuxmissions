#!/bin/bash
find . -type f \( -perm -4000 -o -perm -2000 \) > suid_files.txt
