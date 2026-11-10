#!/bin/bash
./atq                               # job 3 is the cleanup at 03:30 tomorrow
./at -c 3 | tail -n 1               # confirm what job 3 runs
./atrm 3
echo './cleanup.sh' | ./at 23:30
./atq
