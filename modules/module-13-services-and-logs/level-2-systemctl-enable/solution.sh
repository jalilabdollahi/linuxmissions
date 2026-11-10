#!/bin/bash
export PATH="$PWD/bin:$PATH"   # the game shell already has bin/ first on PATH
# "enabled", yet not started at boot: enabled for which target?
systemctl status metrics-agent
systemctl is-enabled metrics-agent
ls -l etc/systemd/system/*.wants/
systemctl get-default
# The server boots multi-user.target; the unit asks for graphical.target.
sed -i 's/^WantedBy=graphical.target$/WantedBy=multi-user.target/' etc/systemd/system/metrics-agent.service
# reenable = disable (drops the old link) + enable (creates the new one); --now starts it.
systemctl reenable --now metrics-agent
systemctl status metrics-agent
