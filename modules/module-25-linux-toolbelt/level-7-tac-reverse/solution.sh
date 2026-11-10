#!/bin/bash
# The record starts at a ---- line: -s sets the separator, -b attaches it to the
# front of each record instead of the end.
tac -b -s '----' CHANGES > CHANGES.newest-first
head -8 CHANGES.newest-first
