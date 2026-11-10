#!/bin/bash
# One run: merge stderr into the pipe, count, and keep the first command's status.
./build.sh 2>&1 | grep -c WARN > warn_count.txt; echo "${PIPESTATUS[0]}" > build_status.txt
cat warn_count.txt build_status.txt
