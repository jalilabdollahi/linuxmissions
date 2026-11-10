#!/bin/bash
export PATH="$PWD/bin:$PATH"   # the game shell already has bin/ first on PATH
cat opt/api/README
systemctl status api
systemctl reload api            # fails: Job type reload is not applicable
# Teach systemd how to reload the api: SIGHUP to the main process.
sed -i 's/^ExecStart=.*/&\nExecReload=\/bin\/kill -HUP $MAINPID/' etc/systemd/system/api.service
systemctl daemon-reload         # systemd re-reads the unit file
systemctl reload api            # the api re-reads its own config
systemctl status api
tail -n 3 var/log/api/api.log
