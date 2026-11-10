#!/bin/bash
# Reference solution: locate the file by name, then pull out the value.
find . -name secret.conf
cat ./var/lib/billing/state/vault/secret.conf
grep '^access_code=' ./var/lib/billing/state/vault/secret.conf | cut -d= -f2 > answer.txt
