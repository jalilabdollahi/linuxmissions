#!/bin/bash
./process.sh &
jobs -l > jobs.txt
wait
