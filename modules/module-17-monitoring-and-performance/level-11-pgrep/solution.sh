#!/bin/bash
sup=$(pgrep -f 'supervisor.sh B$')
pgrep -f -P "$sup" -- '--queue=emails( |$)' > emails_b.txt
