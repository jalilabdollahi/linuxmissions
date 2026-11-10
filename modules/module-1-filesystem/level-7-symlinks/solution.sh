#!/bin/bash
# Reference solution: replace the link from inside its own folder.
cd etc/myapp
ls -l
ln -sf v2/config.conf active.conf
readlink active.conf
