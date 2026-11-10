#!/bin/bash
ps -eo pid,ni,cmd | awk '/opt\/jobs\/batch-/ && !/awk/ && $2 < 10 {print $1}' > violators.txt
