#!/bin/bash
# Every name of the same file shares its inode. List them (hidden dirs included),
# delete all but data/big.dat, then check the link count.
ls -li data/big.dat
find . -samefile data/big.dat
find . -samefile data/big.dat ! -path ./data/big.dat -delete
stat -c 'links: %h' data/big.dat
