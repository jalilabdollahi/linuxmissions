#!/bin/bash
setsid -f ./consumer.sh < /dev/null >> logs/consumer.log 2>&1
sleep 1
ps -o pid,sid,tty,cmd -p "$(pgrep -f "$PWD/consumer.sh")"
