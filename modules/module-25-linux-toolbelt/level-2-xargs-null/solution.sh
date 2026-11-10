#!/bin/bash
# NUL-separated names survive spaces, quotes and newlines.
find photos -type f -name '*.thumb' -print0 | xargs -0 rm
