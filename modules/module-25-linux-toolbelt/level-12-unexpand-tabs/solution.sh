#!/bin/bash
# 1. awk only decides WHICH lines are recipe lines and prints their line numbers.
awk '
/^[^ \t#]/ { rule = ($0 ~ /^[^=:]*:([^=]|$)/ && $0 !~ /^\./) }
/^[ \t]*$/ { rule = 0 }
/^        [^ ]/ && rule { print NR }
' Makefile > recipe.lines
# 2. Only those lines go through unexpand, which turns the 8 leading spaces into a tab.
n=0
while IFS= read -r line; do
  n=$((n + 1))
  if grep -qx "$n" recipe.lines; then
    printf '%s\n' "$line" | unexpand --first-only -t 8
  else
    printf '%s\n' "$line"
  fi
done < Makefile > Makefile.new && mv Makefile.new Makefile
rm recipe.lines
grep -nP '^\t' Makefile | head -5
