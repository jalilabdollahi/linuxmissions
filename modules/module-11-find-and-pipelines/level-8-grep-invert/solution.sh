#!/bin/bash
# Drop lines that are empty, whitespace-only, or start with # after optional whitespace.
grep -v -E '^[[:space:]]*(#|$)' postgresql.conf > effective.conf
wc -l effective.conf
cat effective.conf
