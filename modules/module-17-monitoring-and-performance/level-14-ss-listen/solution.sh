#!/bin/bash
ss -ltn | awk 'NR>1 && $2>$3 {n=split($4,a,":"); print a[n]}' > port.txt
