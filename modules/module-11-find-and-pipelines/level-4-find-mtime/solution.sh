#!/bin/bash
# -mtime -1: modified less than one whole day (24 h) ago.
find etc -type f -mtime -1 > recent.txt
ls -l $(cat recent.txt)
