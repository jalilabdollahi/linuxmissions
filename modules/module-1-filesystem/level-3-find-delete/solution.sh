#!/bin/bash
# Reference solution: preview, then delete with the same expression.
find . -type f -name '*.tmp'
find . -type f -name '*.tmp' -delete
