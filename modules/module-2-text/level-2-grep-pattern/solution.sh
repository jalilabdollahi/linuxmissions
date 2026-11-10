#!/bin/bash
# Reference solution: one pass, two alternatives.
grep -E 'ERROR|FATAL' app.log > errors.txt
wc -l errors.txt
