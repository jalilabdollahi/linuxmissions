#!/bin/bash
# yes repeats "y" forever; the installer stops reading, yes gets SIGPIPE and ends.
yes | ./install.sh
# yes ping repeats "ping"; head takes 1000 lines and closes the pipe.
yes ping | head -n 1000 > load.txt
