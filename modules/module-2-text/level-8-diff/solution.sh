#!/bin/bash
# Reference solution: old file first, new file second, unified format.
diff -u v1.conf v2.conf > changes.diff
cat changes.diff
