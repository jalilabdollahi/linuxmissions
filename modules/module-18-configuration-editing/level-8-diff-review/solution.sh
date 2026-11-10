#!/bin/bash
# Ignore whitespace changes (-w) and blank lines (-B); what is left are real changes.
diff -u -w -B haproxy.orig.cfg haproxy.cfg
diff -w -B haproxy.orig.cfg haproxy.cfg | grep '^>' | awk '{ print $2 }' | sort -u > changed.txt
cat changed.txt
