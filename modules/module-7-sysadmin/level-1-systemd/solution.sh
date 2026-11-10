#!/bin/bash
# Look first: ./systemctl status myapp ; ls -l opt/myapp ; ./systemctl cat myapp
# 1. Point ExecStart at the binary of the new release layout.
sed 's|^ExecStart=/opt/myapp/bin/myapp|ExecStart=/opt/myapp/current/bin/myapp|' \
  etc/systemd/system/myapp.service > myapp.service.new
mv myapp.service.new etc/systemd/system/myapp.service
# 2. Give the unit an [Install] section so it can be enabled at boot.
printf '\n[Install]\nWantedBy=multi-user.target\n' >> etc/systemd/system/myapp.service
# 3. Make systemd re-read the unit, then enable and start it.
./systemctl daemon-reload
./systemctl enable --now myapp.service
./systemctl status myapp.service
