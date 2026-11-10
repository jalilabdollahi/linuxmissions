#!/bin/bash
sed -i 's/pidof queue-worker.sh/pidof -x queue-worker.sh/' healthcheck.sh
