#!/bin/bash
# Wargame 23: webapp fails to start after a "migration". A chain of causes:
#   1. ExecStart is relative / a bare name (the unit refuses to load)
#   2. WorkingDirectory points to the old layout (200/CHDIR)
#   3. a migration drop-in adds an EnvironmentFile that overrides PORT with the
#      port legacy listens on, and DATA_DIR with an old path
#   4. the data directory the app needs does not exist
# legacy (mock HTTP server under the mock systemd) must keep running.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
rm -rf bin etc opt var run usr .lm TICKET.txt .net
mkdir -p bin etc/systemd/system/webapp.service.d etc/webapp etc/legacy opt/webapp opt/legacy var/lib var/log .lm
cp "$M/systemd/systemctl" "$M/systemd/journalctl" bin/
cp "$M/net/http_server.py" opt/legacy/
echo app-07 > etc/hostname
ln -s /usr/lib/systemd/system/multi-user.target etc/systemd/system/default.target

free_port() { python3 -c 'import random,socket
while True:
    p=random.randint(18100,18900); s=socket.socket()
    try: s.bind(("127.0.0.1",p)); s.close(); print(p); break
    except OSError: pass'; }
PORT_WEB=$(free_port); PORT_LEG=$(free_port)
while [ "$PORT_LEG" = "$PORT_WEB" ]; do PORT_LEG=$(free_port); done
OLDWD=$(shuf -n1 -e /srv/webapp /srv/web/current /opt/webapp-v1)
OLDDATA=$(shuf -n1 -e /var/lib/webapp-old /mnt/data/webapp /srv/webapp-data)
DROPIN=$(shuf -n1 -e 10-migration.conf 50-legacy-compat.conf 90-cutover.conf)
REL=$(shuf -n1 -e ./app.py app.py bin/app.py)

cat > opt/webapp/app.py <<'APP'
#!/usr/bin/env python3
import http.server, os, socketserver, sys
root = os.environ.get("LM_ROOT", "")
port = int(os.environ.get("PORT", "0") or 0)
data = os.environ.get("DATA_DIR", "")
if not port:
    print("webapp: PORT is not set", flush=True); sys.exit(2)
d = root + data
if not data or not os.path.isdir(d) or not os.access(d, os.W_OK):
    print("webapp: data directory %s is missing or not writable" % data, flush=True); sys.exit(3)
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"ok webapp\n" if self.path == "/health" else b"webapp\n"
        self.send_response(200 if self.path in ("/health", "/") else 404)
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
class S(socketserver.TCPServer): allow_reuse_address = True
try:
    srv = S(("127.0.0.1", port), H)
except OSError as e:
    print("webapp: cannot bind 127.0.0.1:%d: %s" % (port, e.strerror), flush=True); sys.exit(98)
print("webapp: listening on 127.0.0.1:%d, data in %s" % (port, data), flush=True)
srv.serve_forever()
APP

cat > etc/systemd/system/webapp.service <<UNIT
[Unit]
Description=Customer web application
After=network.target

[Service]
Type=exec
WorkingDirectory=$OLDWD
EnvironmentFile=/etc/webapp/webapp.env
ExecStart=$REL
Restart=no

[Install]
WantedBy=multi-user.target
UNIT
printf 'PORT=%s\r\nDATA_DIR=/var/lib/webapp\r\nWORKERS=2\r\n' "$PORT_WEB" > etc/webapp/webapp.env
cat > etc/systemd/system/webapp.service.d/$DROPIN <<DI
# added during the migration to keep the old cut-over settings
[Service]
EnvironmentFile=/etc/webapp/cutover.env
DI
printf '# cut-over settings from the old host\nPORT=%s\nDATA_DIR=%s\n' "$PORT_LEG" "$OLDDATA" > etc/webapp/cutover.env

cat > etc/legacy/http.json <<'JS'
{"server": "legacy-httpd/0.9", "routes": [{"path": "/health", "body": "legacy ok\n"}, {"path": "/*", "body": "legacy billing portal\n"}]}
JS
cat > etc/systemd/system/legacy.service <<UNIT
[Unit]
Description=Legacy billing portal

[Service]
Type=exec
ExecStart=/usr/bin/python3 /opt/legacy/http_server.py --config /etc/legacy/http.json --port $PORT_LEG --idle-timeout 0 --max-lifetime 0
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
./bin/systemctl daemon-reload
./bin/systemctl start legacy >/dev/null 2>&1
for i in $(seq 1 50); do curl -fs "http://127.0.0.1:$PORT_LEG/health" >/dev/null 2>&1 && break; sleep 0.2; done
./bin/systemctl show -P MainPID legacy > .lm/legacy.pid
echo "$PORT_WEB" > .lm/port; echo "$PORT_LEG" > .lm/legacy.port
cat > TICKET.txt <<TXT
OPS-2291  webapp 502 after migration
Assigned port for webapp: $PORT_WEB  (127.0.0.1)
The old billing portal ("legacy") stays on this host for now. Do not stop, restart or move it.
Everything webapp needs now lives under /opt/webapp, state under /var/lib/webapp.
TXT
exit 0
