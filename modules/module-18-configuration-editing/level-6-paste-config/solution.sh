#!/bin/bash
# paste pairs the lists line by line; grep . drops the blank line of ports.txt;
# a second paste -s joins the pairs into one comma separated line.
echo "BACKENDS=$(paste -d: hosts.txt <(grep . ports.txt) | paste -sd, -)" >> lb.env
tail -n 2 lb.env
