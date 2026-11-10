#!/bin/bash
# Starts a small HTTP API on 127.0.0.1 (random free port) for this level.
# No internet needed: curl talks to it over the loopback interface.
SANDBOX="$1"
API="$SANDBOX/.api"
mkdir -p "$API"

statuses=(degraded maintenance recovering read-only)
echo "${statuses[$((RANDOM % ${#statuses[@]}))]}" > "$API/status"
printf 'lm-%04x%04x%04x\n' $RANDOM $RANDOM $RANDOM > "$SANDBOX/api.key"
: > "$API/access.log"
rm -f "$SANDBOX/api_url.txt"

cat > "$API/server.py" <<'PY'
"""metrics-api stand-in for LinuxMissions. Usage: server.py SANDBOX"""
import json, os, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sandbox = sys.argv[1]
api = os.path.join(sandbox, ".api")
key = open(os.path.join(sandbox, "api.key")).read().strip()
status = open(os.path.join(api, "status")).read().strip()


class Handler(BaseHTTPRequestHandler):
    server_version = "metrics-api/2.4.1"
    protocol_version = "HTTP/1.1"

    def version_string(self):
        return self.server_version

    def send_json(self, code, body, extra=None):
        data = (json.dumps(body, indent=2) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/") or "/"
        authed = self.headers.get("X-API-Key", "").strip() == key
        if path == "/":
            code = 200
            self.send_json(200, {"service": "metrics-api", "endpoints": ["/health", "/metrics"],
                                 "auth": "send your key in the X-API-Key header"})
        elif path in ("/health", "/metrics") and not authed:
            code = 401
            self.send_json(401, {"error": "unauthorized",
                                 "message": "missing or invalid X-API-Key header"},
                           {"WWW-Authenticate": "ApiKey"})
        elif path == "/health":
            code = 200
            self.send_json(200, {
                "service": {"name": "metrics-api", "version": "2.4.1",
                            "status": status, "uptime_seconds": 86231},
                "checks": [
                    {"name": "database", "status": "ok", "latency_ms": 4},
                    {"name": "queue", "status": "ok", "latency_ms": 11},
                    {"name": "disk", "status": "warning", "free_percent": 9},
                ],
            })
        elif path == "/metrics":
            code = 200
            self.send_json(200, {"requests_per_second": 412.7, "error_rate": 0.031})
        else:
            code = 404
            self.send_json(404, {"error": "not found", "path": path})
        with open(os.path.join(api, "access.log"), "a") as log:
            log.write(f"{self.command} {path} {code} auth={'ok' if authed else 'no'}\n")

    do_HEAD = do_GET

    def log_message(self, *args):
        pass


httpd = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
port = httpd.server_address[1]
tmp = os.path.join(sandbox, ".api_url.tmp")
with open(tmp, "w") as f:
    f.write(f"http://127.0.0.1:{port}\n")
os.replace(tmp, os.path.join(sandbox, "api_url.txt"))
threading.Timer(6 * 3600, os._exit, [0]).start()   # never outlive a session by much
httpd.serve_forever()
PY

nohup python3 "$API/server.py" "$SANDBOX" >/dev/null 2>&1 &

for _ in $(seq 1 50); do
  [ -s "$SANDBOX/api_url.txt" ] && exit 0
  sleep 0.1
done
echo "could not start the local API server (is python3 installed?)" >&2
exit 1
