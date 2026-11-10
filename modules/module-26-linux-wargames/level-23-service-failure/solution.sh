#!/bin/bash
export PATH="$PWD/bin:$PATH"
systemctl status webapp | head -20
systemctl cat webapp
cat etc/webapp/*.env
ls etc/systemd/system/webapp.service.d/
rm etc/systemd/system/webapp.service.d/*.conf
sed -i -e 's|^ExecStart=.*|ExecStart=/usr/bin/python3 /opt/webapp/app.py|' -e 's|^WorkingDirectory=.*|WorkingDirectory=/opt/webapp|' etc/systemd/system/webapp.service
mkdir -p var/lib/webapp
systemctl daemon-reload
systemctl restart webapp
sleep 1
curl -s "http://127.0.0.1:$(sed -n 's/^PORT=\([0-9]*\).*/\1/p' etc/webapp/webapp.env)/health"
