#!/bin/bash
renice 15 -p "$(pgrep -f heavy.sh)"
