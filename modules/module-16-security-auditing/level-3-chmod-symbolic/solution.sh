#!/bin/bash
# go-w removes write for group and others; o=rX gives others read, plus execute
# only on directories and files that already have an x bit somewhere.
ls -lR etc-app | head -20
chmod -R go-w,o=rX etc-app
ls -lR etc-app | head -20
