#!/bin/bash
# Reference solution: reveal hidden entries, read the file, keep the value.
ls -a
ls -a .config/app
cat .config/app/.credentials
grep '^AUTH_TOKEN=' .config/app/.credentials | cut -d= -f2 > token.txt
