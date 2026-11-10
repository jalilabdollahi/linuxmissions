#!/bin/bash
res() { p=$1; n=0; while [ -L "$p" ] && [ $n -lt 40 ]; do t=$(readlink "$p"); case $t in /*) p=sysroot$t;; *) p=$(dirname "$p")/$t;; esac; n=$((n+1)); done; [ $n -lt 40 ] && [ -e "$p" ]; }
for l in $(find sysroot -type l); do res "$l" || echo "${l#sysroot/}"; done | sort > broken_links.txt; cat broken_links.txt
ln -sfn /usr/bin/$(ls sysroot/usr/bin | grep '^python3\.' | head -n1) sysroot/etc/alternatives/python3
ln -sfn /usr/bin/vim.tiny sysroot/etc/alternatives/editor
ln -sfn /usr/bin/mawk sysroot/etc/alternatives/awk
