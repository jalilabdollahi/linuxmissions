#!/usr/bin/env python3
"""app: a toy application server for the LinuxMissions release-ops module.

  app daemon --root DIR      serve /health on 127.0.0.1 (port from DIR/app.port), pid in DIR/run/app.pid

The server resolves DIR/current to a release directory when it starts and again on SIGHUP
(like an app that keeps its code open). /health is 200 when the loaded release's app.conf
'schema' equals the number in DIR/data/db.schema, otherwise 500 with a reason.
"""
import http.server, json, os, re, signal, socketserver, sys

STATE = {"release": None}


def load(root):
    cur = os.path.join(root, "current")
    STATE["release"] = os.path.realpath(cur) if os.path.exists(cur) else None
    sys.stderr.write(f"app[{os.getpid()}]: loaded release {STATE['release']}\n")
    sys.stderr.flush()


def health(root):
    rel = STATE["release"]
    if not rel or not os.path.isdir(rel):
        return 500, {"status": "error", "version": None, "error": "no release loaded"}
    try:
        version = open(os.path.join(rel, "VERSION")).read().strip()
        conf = open(os.path.join(rel, "app.conf")).read()
        want = re.search(r"^schema\s*=\s*(\d+)", conf, re.M).group(1)
        have = open(os.path.join(root, "data", "db.schema")).read().strip()
    except (OSError, AttributeError):
        return 500, {"status": "error", "version": None, "error": "release is incomplete"}
    if want != have:
        return 500, {"status": "error", "version": version, "error": f"schema mismatch: release needs {want}, database has {have}"}
    return 200, {"status": "ok", "version": version}


def make_handler(root):
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def do_GET(self):
            if self.path.split("?")[0] == "/health":
                code, obj = health(root)
            else:
                code, obj = 404, {"error": "not found"}
            body = (json.dumps(obj) + "\n").encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    return H


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main(argv):
    args = dict(zip(argv[1::2], argv[2::2]))
    if not argv or argv[0] != "daemon" or "--root" not in args:
        print(__doc__)
        return 2
    root = os.path.abspath(args["--root"])
    port = int(open(os.path.join(root, "app.port")).read())
    load(root)
    signal.signal(signal.SIGHUP, lambda *_: load(root))
    srv = Server(("127.0.0.1", port), make_handler(root))
    os.makedirs(os.path.join(root, "run"), exist_ok=True)
    open(os.path.join(root, "run", "app.pid"), "w").write(f"{os.getpid()}\n")
    srv.serve_forever()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
