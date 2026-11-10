#!/bin/bash
# One capture, split three ways with tee.
./gen-events | tee events.raw | grep 'level=error' | tee errors.log | wc -l > error_count.txt
cat error_count.txt
