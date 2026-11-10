#!/usr/bin/env python3
"""pricer: a toy pricing daemon for the LinuxMissions release-ops module.

  pricer --check FILE                       validate a config file (exit 0 ok, 1 invalid)
  pricer daemon --config FILE --pidfile F   run the daemon (foreground)

The daemon re-reads its config file on SIGHUP and keeps serving open connections. If the
new file is invalid it logs the problem and exits (a bad reload kills the daemon).
Endpoints on 127.0.0.1:listen_port: /version  /quote?base=N  /stream (a long-lived feed).
"""
import http.server, json, os, re, signal, socketserver, sys, threading, time, urllib.parse

KEYS = {
    "config_version": lambda v: re.fullmatch(r"\d+\.\d+", v) and v,
    "listen_port": lambda v: v.isdigit() and 1024 <= int(v) <= 65535 and int(v),
    "currency": lambda v: v in ("EUR", "USD", "GBP") and v,
    "markup_pct": lambda v: v.isdigit() and 0 <= int(v) <= 100 and int(v),
    "timeout_ms": lambda v: v.isdigit() and 100 <= int(v) <= 60000 and int(v),
}
WHAT = {"config_version": "a version like 1.5", "listen_port": "a port number", "currency": "EUR, USD or GBP",
        "markup_pct": "an integer from 0 to 100", "timeout_ms": "an integer from 100 to 60000"}


def parse(path):
    """Return (config dict, list of 'file:line: message' errors)."""
    cfg, errs = {}, []
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError as e:
        return {}, [f"{path}: cannot read: {e.strerror}"]
    for n, line in enumerate(lines, 1):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if "=" not in s:
            errs.append(f"{path}:{n}: expected 'key = value'")
            continue
        k, v = (x.strip() for x in s.split("=", 1))
        if k not in KEYS:
            errs.append(f"{path}:{n}: unknown key '{k}'")
            continue
        val = KEYS[k](v)
        if val is False or val is None or val == "":
            errs.append(f"{path}:{n}: {k}: '{v}' is not valid (expected {WHAT[k]})")
            continue
        cfg[k] = val
    for k in KEYS:
        if k not in cfg and not errs:
            errs.append(f"{path}: missing key '{k}'")
    return cfg, errs


STATE = {"cfg": {}, "reloads": 0}


def reload(path):
    cfg, errs = parse(path)
    if errs:
        for e in errs:
            sys.stderr.write(f"pricer[{os.getpid()}]: reload failed: {e}\n")
        sys.stderr.write(f"pricer[{os.getpid()}]: invalid configuration, exiting\n")
        sys.stderr.flush()
        os._exit(1)
    STATE["cfg"] = cfg
    STATE["reloads"] += 1
    sys.stderr.write(f"pricer[{os.getpid()}]: reloaded configuration, config_version={cfg['config_version']}\n")
    sys.stderr.flush()


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        body = (json.dumps(obj) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        cfg = STATE["cfg"]
        if u.path == "/version":
            self._json({"daemon": "pricer", "pid": os.getpid(), "config": cfg["config_version"],
                        "markup_pct": cfg["markup_pct"], "currency": cfg["currency"], "reloads": STATE["reloads"]})
        elif u.path == "/quote":
            q = urllib.parse.parse_qs(u.query)
            base = float(q.get("base", ["100"])[0])
            self._json({"price": round(base * (1 + cfg["markup_pct"] / 100), 2), "currency": cfg["currency"]})
        elif u.path == "/stream":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            n = 0
            try:
                while True:
                    n += 1
                    self.wfile.write(f"tick {n} markup={STATE['cfg']['markup_pct']}\n".encode())
                    self.wfile.flush()
                    time.sleep(0.4)
            except OSError:
                pass
        else:
            self._json({"error": "not found"}, 404)


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main(argv):
    if len(argv) == 2 and argv[0] == "--check":
        cfg, errs = parse(argv[1])
        if errs:
            for e in errs:
                print(e)
            print(f"pricer: {argv[1]}: {len(errs)} error(s), config rejected")
            return 1
        print(f"pricer: {argv[1]}: config OK (version {cfg['config_version']})")
        return 0
    if argv and argv[0] == "daemon":
        args = dict(zip(argv[1::2], argv[2::2]))
        path, pidfile = args.get("--config"), args.get("--pidfile")
        if not path or not pidfile:
            print(__doc__)
            return 2
        cfg, errs = parse(path)
        if errs:
            for e in errs:
                sys.stderr.write(e + "\n")
            return 2
        STATE["cfg"] = cfg
        signal.signal(signal.SIGHUP, lambda *_: reload(path))
        srv = Server(("127.0.0.1", cfg["listen_port"]), Handler)
        open(pidfile, "w").write(f"{os.getpid()}\n")
        sys.stderr.write(f"pricer[{os.getpid()}]: started, config_version={cfg['config_version']}\n")
        sys.stderr.flush()
        srv.serve_forever()
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
