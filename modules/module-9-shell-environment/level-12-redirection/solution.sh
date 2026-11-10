#!/bin/bash
./nightly.sh > out.log 2> err.log
./nightly.sh >> all.log 2>&1
./nightly.sh >> all.log 2>&1
cat all.log
