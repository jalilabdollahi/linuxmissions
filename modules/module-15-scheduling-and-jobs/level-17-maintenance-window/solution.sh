#!/bin/bash
sed -i.bak -e '8s/^/#FREEZE /' -e '10s/^/#FREEZE /' -e '12s/^/#FREEZE /' -e '14s/^/#FREEZE /' -e '15s/^/#FREEZE /' -e '22s/^/#FREEZE /' -e '23s/^/#FREEZE /' -e '25s/^/#FREEZE /' crontab.txt
