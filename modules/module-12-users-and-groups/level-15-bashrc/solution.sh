#!/bin/bash
# Guard the file: stop reading it unless the shell is interactive.
sed -i '2i [[ $- == *i* ]] || return' home/kim/.bashrc
head -n 4 home/kim/.bashrc
env -i HOME="$PWD/home/kim" bash -c '. ~/.bashrc; echo OK'
