#!/bin/bash
# umask 002 must come before the first mkdir/write: files 666 -> 664, dirs 777 -> 775.
umask
grep -n 'mkdir' publish.sh
sed -i 's|^OUT=\${1:-shared/reports}$|umask 002\nOUT=${1:-shared/reports}|' publish.sh
cat publish.sh
./publish.sh
ls -lR shared/reports
