#!/bin/bash
pgrep -f debug_logger.sh
kill $(pgrep -f debug_logger.sh)
sleep 0.5
