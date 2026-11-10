#!/bin/bash
# Reference solution: size of every file in KB, smallest to largest, keep the last path.
find . -type f -exec du -k {} + | sort -n | tail -3
find . -type f -exec du -k {} + | sort -n | tail -1 | cut -f2 > biggest.txt
cat biggest.txt
