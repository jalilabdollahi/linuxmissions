#!/bin/bash
./efibootmgr -v
cat blkid.txt
./efibootmgr -o 0003,0000,0004,0001,0002
