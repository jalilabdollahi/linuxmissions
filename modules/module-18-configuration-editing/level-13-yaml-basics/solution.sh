#!/bin/bash
# Fix the two bad indents (tab -> 6 spaces, 9 spaces -> 6 spaces) and bump only the worker line.
sed -i \
  -e 's/^\t/      /' \
  -e 's/^         RETRIES:/      RETRIES:/' \
  -e '/shop\/worker:/s/2\.7\.0/2.7.1/' compose.yml
python3 -c 'import yaml; yaml.safe_load(open("compose.yml")); print("parses")'
