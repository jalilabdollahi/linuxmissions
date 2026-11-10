#!/bin/bash
# Reference solution: regular files only, name ending in .py, saved to found.txt.
find . -type f -name '*.py' > found.txt
cat found.txt
