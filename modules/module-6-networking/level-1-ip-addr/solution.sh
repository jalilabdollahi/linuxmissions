#!/bin/bash
# The label at the end of each "inet" line is the interface the address is on.
awk '$1 == "inet" { split($2, a, "/"); print $NF, a[1] }' ip_addr.txt > interfaces.txt
cat interfaces.txt
