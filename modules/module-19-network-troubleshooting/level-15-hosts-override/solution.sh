#!/bin/bash
# The first etc/hosts line that names db.corp.example (as a word, not a
# comment) answers; remove the alias from that line only.
PATH="$PWD/bin:$PATH"
getent hosts db.corp.example
grep -n -w -F 'db.corp.example' etc/hosts | grep -v '^[0-9]*:#'
line=$(grep -n -w -F 'db.corp.example' etc/hosts | grep -v '^[0-9]*:#' | head -1 | cut -d: -f1)
echo "etc/hosts:$line" > cause.txt
sed -i.bak "${line}s/ db\.corp\.example\$//" etc/hosts
getent hosts db.corp.example
