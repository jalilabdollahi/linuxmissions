#!/bin/bash
find releases -type l > links.txt
find releases -type d -empty > empty-dirs.txt
cat links.txt empty-dirs.txt
