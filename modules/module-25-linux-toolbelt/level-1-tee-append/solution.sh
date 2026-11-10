#!/bin/bash
# 2>&1 sends the warnings down the pipe too; tee -a shows everything and appends it.
./maintenance.sh 2>&1 | tee -a audit.log
