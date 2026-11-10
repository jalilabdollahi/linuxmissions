#!/bin/bash
ps -eo pid,rss,cmd --sort=-rss | grep 'workers/worker.py' | grep -v grep | head -3 | awk '{print $1}' > top_rss.txt
