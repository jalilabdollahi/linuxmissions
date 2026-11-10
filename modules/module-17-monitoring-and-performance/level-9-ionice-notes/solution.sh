#!/bin/bash
tar=$(pgrep -o -f 'tar -czf')
for pid in $tar $(pstree -p "$tar" | grep -o '([0-9]*)' | tr -d '()'); do
  ionice -c3 -p "$pid"
done
