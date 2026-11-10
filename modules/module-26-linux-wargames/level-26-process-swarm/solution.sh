#!/bin/bash
sw=$(pgrep -x swarmd)
pg=$(ps -o pgid= -p "$sw" | tr -d ' ')
for p in $(ps -eo pid=,ppid= | awk -v s="$sw" '$2==s{print $1}'); do
  case "$(tr '\0' ' ' < /proc/$p/cmdline)" in
    '['*) readlink /proc/$p/exe > hidden.txt ;;
  esac
done
kill -9 -- -"$pg"
