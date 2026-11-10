#!/bin/bash
# 1. script runs the command inside a pseudo-terminal and logs everything it prints
#    -q = no start/stop messages on screen, -c = the command to run
#    </dev/null: script must not read the game shell's keyboard input, or it swallows the next commands
script -q -c ./vendor-diag diag.typescript </dev/null
# 2. clean the log:
#    s/\x1b\[[0-9;?]*[A-Za-z]//g  remove colour and erase codes
#    s/\r$//                      the terminal ends every line with \r\n
#    s/.*\r//                     a \r means "back to column 0": keep what was written last
#    grep -avE '^(Script |$)'     drop the lines script itself adds (and its blank line)
sed 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\r$//; s/.*\r//' diag.typescript | grep -avE '^(Script |$)' > diag.txt
cat diag.txt
