#!/bin/bash
# Drop the empty line from the key list, then search for the keys as fixed strings.
grep -v '^$' leaked.txt > keys.txt
grep -rF -f keys.txt logs > hits.txt
wc -l hits.txt
