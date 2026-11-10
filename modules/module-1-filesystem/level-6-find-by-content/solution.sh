#!/bin/bash
# Reference solution: search contents recursively, print only file names.
grep -rl 'password=' . > leak.txt
cat leak.txt
