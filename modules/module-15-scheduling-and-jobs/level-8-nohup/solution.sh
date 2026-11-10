#!/bin/bash
nohup ./migrate.sh > logs/migrate.log 2>&1 &
sleep 2
tail -n 2 logs/migrate.log
