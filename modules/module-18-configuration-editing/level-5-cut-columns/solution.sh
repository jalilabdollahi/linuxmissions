#!/bin/bash
# Names: drop comments and blanks, strip "export ", cut at the first "=".
# Key: print everything after the first "=" (-f2- keeps later "=" signs).
grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' prod.env | sed 's/^export //' | cut -d= -f1 > keys.txt
grep '^SIGNING_KEY=' prod.env | cut -d= -f2- > signing_key.txt
cat keys.txt signing_key.txt
