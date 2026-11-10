#!/bin/bash
# Delete the CRs, lowercase, turn every space, tab and dot into _ and squeeze.
cat -A newhires.txt | head -5
tr -d '\r' < newhires.txt | tr 'A-Z' 'a-z' | tr -s ' \t.' '_' > usernames.txt
head usernames.txt
