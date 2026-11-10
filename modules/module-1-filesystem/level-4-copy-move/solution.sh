#!/bin/bash
# Reference solution: back up first, then move, then rename.
cp production/app.conf production/app.conf.old
mv staging/*.conf production/
mv staging/app.conf.new production/app.conf
ls staging production
