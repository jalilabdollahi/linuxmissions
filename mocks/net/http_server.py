#!/usr/bin/env python3
"""LinuxMissions mock HTTP/1.1 server (python3 stdlib only).

Serves routes from a JSON config on 127.0.0.1 for curl / wget levels:
status codes, headers, bodies or files, static directory trees, redirect
chains and loops, basic/bearer auth (401), required headers or cookies (403),
slow and hanging responses, throttled and interrupted downloads, Range /
resume (curl -C -, wget -c), chunked transfer, gzip, conditional requests
(ETag / Last-Modified -> 304), per-method overrides (HEAD != GET), responses
that rotate per request, connection reset / empty reply, an optional forward
proxy mode and optional TLS. Writes an nginx "combined" access log.

Start (from a level's setup.sh; returns once the server is listening):

    python3 "$NET/http_server.py" --config "$NET/http.json" --port 0 \
        --port-file "$NET/http.port" --log "$NET/access.log" --daemon

See mocks/README.md for the config format.
"""
from __future__ import annotations

import argparse
import base64
import email.utils
import gzip
import html
import json
import mimetypes
import os
import select
import socket
import ssl
import sys
import threading
import time
from http.cookies import CookieError, SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit


# --------------------------------------------------------------------------
# Shared runtime helpers (same block in every mocks/net server)
# --------------------------------------------------------------------------
def write_atomic(path: str, text: str) -> None:
    tmp = f"{path}.tmp{os.getpid()}"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def wait_ready(path: str, timeout: float) -> int:
    """--wait-ready: block until a port file exists and is non-empty."""
    end = time.time() + timeout
    while time.time() < end:
        try:
            with open(path) as f:
                text = f.read()
            if text.strip():
                sys.stdout.write(text)
                return 0
        except OSError:
            pass
        time.sleep(0.05)
    sys.stderr.write(f"timed out after {timeout}s waiting for {path}\n")
    return 1


def daemonize(pid_file: str | None) -> None:
    """Fork into the background; the parent exits 0 once sockets are bound."""
    sys.stdout.flush()
    sys.stderr.flush()
    if os.fork():
        os._exit(0)
    os.setsid()
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)
    if pid_file:
        write_atomic(pid_file, f"{os.getpid()}\n")


class Lifetime:
    """Exit after `idle` seconds without use or `max_life` seconds in total."""

    def __init__(self, idle: float, max_life: float):
        self.idle, self.max_life = idle, max_life
        self.start = self.last = time.monotonic()
        threading.Thread(target=self._watch, daemon=True).start()

    def touch(self) -> None:
        self.last = time.monotonic()

    def _watch(self) -> None:
        while True:
            time.sleep(1)
            now = time.monotonic()
            if (self.idle and now - self.last > self.idle) or (self.max_life and now - self.start > self.max_life):
                os._exit(0)


def add_common_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--host", default="127.0.0.1", help="address to bind (default 127.0.0.1)")
    p.add_argument("--port", type=int, default=0, help="port to bind, 0 = pick a free one (default)")
    p.add_argument("--port-file", help="write the bound port here once listening (atomic; doubles as ready file)")
    p.add_argument("--pid-file", help="write the server PID here")
    p.add_argument("--daemon", action="store_true", help="fork to background, return once listening")
    p.add_argument("--idle-timeout", type=float, default=7200, help="exit after this many idle seconds (0 = never)")
    p.add_argument("--max-lifetime", type=float, default=21600, help="exit after this many seconds (0 = never)")
    p.add_argument("--wait-ready", metavar="PORT_FILE", help="don't serve: wait for PORT_FILE, print it, exit")
    p.add_argument("--timeout", type=float, default=10, help="seconds --wait-ready waits (default 10)")


class LineLog:
    def __init__(self, path: str | None):
        self.path, self.lock = path, threading.Lock()
        if path:
            open(path, "a").close()

    def write(self, line: str) -> None:
        if not self.path:
            return
        with self.lock:
            try:
                with open(self.path, "a") as f:
                    f.write(line + "\n")
            except OSError:
                pass


# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------
class ConfigError(Exception):
    pass


ROUTE_KEYS = {
    "path", "host", "methods", "status", "reason", "headers", "body", "file", "json", "dir",
    "autoindex", "content_type", "redirect", "delay", "hang", "rate", "abort_after", "chunked",
    "gzip", "ranges", "auth", "require_headers", "require_cookies", "deny_status", "deny_body",
    "by_method", "cycle", "action", "comment",
}


class Config:
    def __init__(self, path: str):
        self.path = os.path.abspath(path)
        self.base = os.path.dirname(self.path)
        try:
            with open(self.path, encoding="utf-8") as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            raise ConfigError(f"{path}: invalid JSON: {e}") from None
        if not isinstance(data, dict) or not isinstance(data.get("routes", []), list):
            raise ConfigError(f"{path}: expected an object with a \"routes\" list")
        self.server = data.get("server", "nginx/1.24.0")
        self.tls = data.get("tls")
        self.log_headers = list(data.get("log_headers", []))
        self.routes = data.get("routes", [])
        for i, r in enumerate(self.routes):
            where = f"{path}: route {i}"
            if not isinstance(r, dict) or not isinstance(r.get("path"), str) or not r["path"].startswith("/"):
                raise ConfigError(f"{where}: every route needs a \"path\" starting with /")
            for sub in [r] + list(r.get("by_method", {}).values()) + list(r.get("cycle", [])):
                bad = set(sub) - ROUTE_KEYS
                if bad:
                    raise ConfigError(f"{where}: unknown key(s) {', '.join(sorted(bad))}")
            if r.get("action") not in (None, "reset", "close"):
                raise ConfigError(f"{where}: action must be \"reset\" or \"close\"")

    def resolve(self, rel: str) -> str:
        return rel if os.path.isabs(rel) else os.path.join(self.base, rel)

    def match(self, host: str, path: str):
        """First route whose path (and host, if set) matches; (index, route)."""
        for i, r in enumerate(self.routes):
            rh = r.get("host")
            if rh and rh.lower() != host:
                continue
            p = r["path"]
            if p.endswith("*") and path.startswith(p[:-1]) or path == p:
                return i, r
        return None, None


def status_page(code: int, reason: str, server: str) -> bytes:
    title = f"{code} {reason}"
    sig = f"<hr><center>{html.escape(server)}</center>\r\n" if server else ""
    return (f"<html>\r\n<head><title>{title}</title></head>\r\n<body>\r\n"
            f"<center><h1>{title}</h1></center>\r\n{sig}</body>\r\n</html>\r\n").encode()


class Response:
    def __init__(self, status=200, body=b"", ctype="text/html"):
        self.status, self.reason, self.body, self.ctype = status, None, body, ctype
        self.headers: list[tuple[str, str]] = []
        self.delay = self.rate = 0.0
        self.abort_after = None
        self.chunked = self.gzip = False
        self.ranges = True
        self.action = None
        self.page = False  # body is a generated status page

    def has(self, name):
        return any(k.lower() == name.lower() for k, _ in self.headers)

    def get(self, name):
        return next((v for k, v in self.headers if k.lower() == name.lower()), None)


# --------------------------------------------------------------------------
# Request handling
# --------------------------------------------------------------------------
class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    timeout = 120
    srv = None  # set in serve()

    def version_string(self):
        return self.srv.config.server

    def log_message(self, *args):
        pass

    def setup(self):
        if self.srv.tls_ctx:
            self.request.settimeout(10)
            try:
                self.request = self.srv.tls_ctx.wrap_socket(self.request, server_side=True)
            except (ssl.SSLError, OSError):
                self.request.close()
                raise ConnectionAbortedError from None
            self.connection = self.request
        super().setup()

    def handle(self):
        try:
            super().handle()
        except (ConnectionError, socket.timeout, ssl.SSLError, OSError):
            pass

    def __getattr__(self, name):
        if name.startswith("do_"):
            return self.dispatch
        raise AttributeError(name)

    # -- helpers --------------------------------------------------------
    def read_body(self) -> bytes:
        if "chunked" in self.headers.get("Transfer-Encoding", "").lower():
            out = b""
            while True:
                line = self.rfile.readline(1024)
                size = int(line.split(b";")[0].strip() or b"0", 16)
                if size == 0:
                    while self.rfile.readline(1024) not in (b"\r\n", b"\n", b""):
                        pass
                    return out
                out += self.rfile.read(size)
                self.rfile.readline(16)
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n > 0 else b""

    def cookies(self) -> dict:
        c = SimpleCookie()
        try:
            c.load(self.headers.get("Cookie", ""))
        except CookieError:
            return {}
        return {k: m.value for k, m in c.items()}

    def access_log(self, status, nbytes, user, started):
        srv = self.srv
        ts = time.strftime("%d/%b/%Y:%H:%M:%S %z", time.localtime(started))
        ref = self.headers.get("Referer", "-") if self.headers else "-"
        ua = self.headers.get("User-Agent", "-") if self.headers else "-"
        host = self.headers.get("Host", "-") if self.headers else "-"
        extra = "".join(f' {h.lower()}="{self.headers.get(h, "-")}"' for h in srv.config.log_headers)
        req = self.requestline.replace('"', '\\"')
        srv.log.write(f'{self.client_address[0]} - {user or "-"} [{ts}] "{req}" {status} {nbytes} '
                      f'"{ref}" "{ua}" host="{host}" rt={time.time() - started:.3f}{extra}')

    # -- main dispatch --------------------------------------------------
    def dispatch(self):
        started = time.time()
        srv = self.srv
        srv.life.touch()
        srv.maybe_reload()
        cfg = srv.config
        target = self.path
        if target.startswith(("http://", "https://")):
            # absolute-form: what clients send to a forward proxy
            u = urlsplit(target)
            host, path = (u.hostname or "").lower(), u.path or "/"
        else:
            host = (self.headers.get("Host") or "").lower()
            host = host.rsplit(":", 1)[0] if not host.endswith("]") else host
            path = target.split("?", 1)[0]
        path = unquote(path)
        try:
            self.read_body()  # drain it so keep-alive stays in sync
        except (ValueError, OSError):
            self.close_connection = True
        user = None
        idx, route = cfg.match(host, path)
        if route is None:
            resp = Response(404, status_page(404, "Not Found", cfg.server))
            resp.page = True
        else:
            route = dict(route)
            if self.command in route.get("by_method", {}):
                route.update(route["by_method"][self.command])
            if route.get("cycle"):
                route.update(srv.next_cycle(idx, route["cycle"]))
            resp, user = self.build(route, path)
        try:
            status, sent = self.send(resp)
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True
            status, sent = 499, 0
        self.access_log(status, sent, user, started)

    def build(self, r: dict, path: str):
        cfg = self.srv.config
        user = None
        methods = [m.upper() for m in r.get("methods", ["GET", "HEAD"])]
        if self.command not in methods:
            resp = Response(405, status_page(405, "Not Allowed", cfg.server))
            resp.headers.append(("Allow", ", ".join(methods)))
            resp.page = True
            return resp, user
        auth = r.get("auth")
        if auth:
            got = self.headers.get("Authorization", "")
            scheme, _, cred = got.partition(" ")
            ok = False
            if scheme.lower() == "basic" and auth.get("basic"):
                try:
                    dec = base64.b64decode(cred.strip(), validate=True).decode("utf-8", "replace")
                except ValueError:
                    dec = ""
                ok = dec in auth["basic"]
                user = dec.split(":", 1)[0] if dec else None
            elif scheme.lower() == "bearer" and auth.get("bearer"):
                ok = cred.strip() in auth["bearer"]
            if not ok:
                realm = auth.get("realm", "Restricted")
                resp = Response(401, status_page(401, "Unauthorized", cfg.server))
                resp.page = True
                resp.headers.append(("WWW-Authenticate", f'Basic realm="{realm}"' if auth.get("basic")
                                     else f'Bearer realm="{realm}"'))
                return resp, (user if scheme.lower() == "basic" else None)
        denied = False
        for name, want in r.get("require_headers", {}).items():
            have = self.headers.get(name)
            if have is None or (want is not None and have.strip() != want):
                denied = True
        if not denied and r.get("require_cookies"):
            jar = self.cookies()
            denied = any(jar.get(k) != v for k, v in r["require_cookies"].items())
        if denied:
            code = int(r.get("deny_status", 403))
            reason = self.responses.get(code, ("Error",))[0]
            body = r.get("deny_body")
            resp = Response(code, body.encode() if body is not None else status_page(code, reason, cfg.server))
            resp.page = body is None
            if body is not None:
                resp.ctype = r.get("content_type", "text/plain")
            return resp, user

        resp = Response(int(r.get("status", 302 if "redirect" in r else 200)))
        resp.reason = r.get("reason")
        if "redirect" in r:
            resp.headers.append(("Location", r["redirect"]))
        if "dir" in r:
            prefix = r["path"][:-1] if r["path"].endswith("*") else r["path"]
            served = self.static(r, path[len(prefix):], resp)
            if served is not None:
                return served, user
        elif "file" in r:
            fpath = cfg.resolve(r["file"])
            try:
                with open(fpath, "rb") as f:
                    resp.body = f.read()
                resp.ctype = mimetypes.guess_type(fpath)[0] or "application/octet-stream"
            except OSError:
                resp = Response(404, status_page(404, "Not Found", cfg.server))
                resp.page = True
                return resp, user
        elif "json" in r:
            resp.body = (json.dumps(r["json"], indent=2) + "\n").encode()
            resp.ctype = "application/json"
        elif "body" in r:
            resp.body = str(r["body"]).encode()
            resp.ctype = "text/plain"
        else:
            reason = resp.reason or self.responses.get(resp.status, ("",))[0]
            resp.body = status_page(resp.status, reason, cfg.server) if resp.status >= 300 else b""
            resp.page = resp.status >= 300
        if "content_type" in r:
            resp.ctype = r["content_type"]
        for k, v in r.get("headers", {}).items():
            for item in (v if isinstance(v, list) else [v]):
                resp.headers.append((k, str(item)))
        resp.delay = float(r.get("delay", 0))
        if r.get("hang"):
            resp.delay = 3600.0
        resp.rate = float(r.get("rate", 0))
        resp.abort_after = r.get("abort_after")
        resp.chunked = bool(r.get("chunked"))
        resp.gzip = bool(r.get("gzip"))
        resp.ranges = bool(r.get("ranges", True))
        resp.action = r.get("action")
        return resp, user

    def static(self, r, rest, resp):
        cfg = self.srv.config
        root = os.path.realpath(cfg.resolve(r["dir"]))
        full = os.path.realpath(os.path.join(root, rest.lstrip("/")))
        if full != root and not full.startswith(root + os.sep):
            return self.not_found()
        if os.path.isdir(full):
            if rest and not rest.endswith("/") or not rest and not self.path.split("?")[0].endswith("/"):
                moved = Response(301, status_page(301, "Moved Permanently", cfg.server))
                moved.page = True
                moved.headers.append(("Location", self.path.split("?")[0] + "/"))
                return moved
            index = os.path.join(full, "index.html")
            if os.path.isfile(index):
                full = index
            elif r.get("autoindex"):
                resp.body = self.autoindex(full, self.path.split("?")[0])
                resp.ctype = "text/html"
                return None
            else:
                forbidden = Response(403, status_page(403, "Forbidden", cfg.server))
                forbidden.page = True
                return forbidden
        if not os.path.isfile(full):
            return self.not_found()
        with open(full, "rb") as f:
            resp.body = f.read()
        resp.ctype = mimetypes.guess_type(full)[0] or "application/octet-stream"
        resp.headers.append(("Last-Modified", email.utils.formatdate(os.path.getmtime(full), usegmt=True)))
        return None

    def not_found(self):
        nf = Response(404, status_page(404, "Not Found", self.srv.config.server))
        nf.page = True
        return nf

    @staticmethod
    def autoindex(full, urlpath):
        rows = []
        for name in sorted(os.listdir(full)):
            p = os.path.join(full, name)
            disp = name + ("/" if os.path.isdir(p) else "")
            mtime = time.strftime("%d-%b-%Y %H:%M", time.gmtime(os.path.getmtime(p)))
            size = "-" if os.path.isdir(p) else str(os.path.getsize(p))
            rows.append(f'<a href="{html.escape(disp)}">{html.escape(disp)}</a>'
                        f'{" " * max(1, 51 - len(disp))}{mtime} {size:>19}')
        t = html.escape(urlpath)
        return (f"<html>\r\n<head><title>Index of {t}</title></head>\r\n<body>\r\n<h1>Index of {t}</h1><hr><pre>"
                f'<a href="../">../</a>\r\n' + "\r\n".join(rows) + "\r\n</pre><hr></body>\r\n</html>\r\n").encode()

    # -- sending ---------------------------------------------------------
    def conditional(self, resp) -> bool:
        etag = resp.get("ETag")
        inm = self.headers.get("If-None-Match")
        if etag and inm:
            tags = [t.strip() for t in inm.split(",")]
            return "*" in tags or etag in tags or etag.lstrip("W/") in [t.lstrip("W/") for t in tags]
        lm, ims = resp.get("Last-Modified"), self.headers.get("If-Modified-Since")
        if lm and ims and not inm:
            try:
                return email.utils.parsedate_to_datetime(lm) <= email.utils.parsedate_to_datetime(ims)
            except (TypeError, ValueError):
                return False
        return False

    def parse_range(self, size):
        """None = ignore the header, (start, end) = satisfiable, False = 416."""
        h = self.headers.get("Range", "")
        if not h.startswith("bytes=") or "," in h:
            return None
        a, _, b = h[6:].strip().partition("-")
        try:
            if a == "":
                n = int(b)
                if n == 0:
                    return False
                return max(0, size - n), size - 1
            start = int(a)
            end = int(b) if b else size - 1
        except ValueError:
            return None
        if start >= size or end < start:
            return False
        return start, min(end, size - 1)

    def client_gone(self) -> bool:
        """True if the client closed the connection (e.g. curl --max-time) while we waited."""
        try:
            r, _, _ = select.select([self.connection], [], [], 0)
            return bool(r) and self.connection.recv(1, socket.MSG_PEEK) == b""
        except (OSError, ValueError, ssl.SSLError):
            return True

    def send(self, resp: Response):
        """Write the response; return (status for the log, body bytes sent)."""
        end = time.monotonic() + resp.delay
        while time.monotonic() < end:  # wait, but notice a client that gives up
            time.sleep(min(0.2, end - time.monotonic()))
            if self.client_gone():
                self.close_connection = True
                return 499, 0
        if resp.action:
            self.close_connection = True
            if resp.action == "reset":
                self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, b"\1\0\0\0\0\0\0\0")
            try:
                self.connection.close()
            except OSError:
                pass
            return 444, 0
        head = self.command == "HEAD"
        status, body = resp.status, resp.body
        extra = []
        if status < 300 and self.conditional(resp):
            status, body = 304, b""
        partial = None
        if status == 200 and not resp.gzip and not resp.chunked and resp.ranges:
            extra.append(("Accept-Ranges", "bytes"))
            if "Range" in self.headers:
                rng = self.parse_range(len(body))
                if rng is False:
                    status = 416
                    extra.append(("Content-Range", f"bytes */{len(body)}"))
                    body = status_page(416, "Requested Range Not Satisfiable", self.srv.config.server)
                    resp.ctype = "text/html"
                elif rng:
                    partial = rng
                    status = 206
                    extra.append(("Content-Range", f"bytes {rng[0]}-{rng[1]}/{len(body)}"))
                    body = body[rng[0]:rng[1] + 1]
        if resp.gzip and status == 200 and "gzip" in self.headers.get("Accept-Encoding", "").lower():
            body = gzip.compress(body, mtime=0)
            extra.append(("Content-Encoding", "gzip"))
        if resp.gzip:
            extra.append(("Vary", "Accept-Encoding"))
        self.send_response(status, resp.reason if status == resp.status else None)
        if status not in (204, 304) and (body or status == 200) and not resp.has("Content-Type"):
            plain_text = resp.ctype.startswith("text/") and "charset" not in resp.ctype and not resp.page
            self.send_header("Content-Type", resp.ctype + ("; charset=utf-8" if plain_text else ""))
        chunked = resp.chunked and status not in (204, 304)
        if chunked:
            self.send_header("Transfer-Encoding", "chunked")
        elif status not in (204, 304):
            self.send_header("Content-Length", str(len(body)))
        for k, v in resp.headers + extra:
            if status == 304 and k.lower() not in ("etag", "cache-control", "expires", "vary", "last-modified"):
                continue
            self.send_header(k, v)
        if resp.abort_after is not None and partial is None and not head:
            self.send_header("Connection", "close")
            self.close_connection = True
        self.end_headers()
        if head or status in (204, 304):
            return status, 0
        limit = len(body)
        if resp.abort_after is not None and partial is None:
            limit = min(limit, int(resp.abort_after))
        sent = 0
        try:
            step = 16384 if not resp.rate else max(1, int(resp.rate / 10))
            while sent < limit:
                piece = body[sent:min(limit, sent + step)]
                self.wfile.write(b"%x\r\n%s\r\n" % (len(piece), piece) if chunked else piece)
                sent += len(piece)
                if resp.rate:
                    time.sleep(len(piece) / resp.rate)
            if limit < len(body):
                self.close_connection = True
                self.connection.shutdown(socket.SHUT_RDWR)
                return status, sent
            if chunked:
                self.wfile.write(b"0\r\n\r\n")
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True
            return 499, sent
        return status, sent


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, args):
        self.args = args
        self.config_path = args.config
        self.config = Config(args.config)
        self.mtime = self._mtime()
        self.log = LineLog(args.log)
        self.cycle_pos: dict = {}
        self.cycle_lock = threading.Lock()
        self.tls_ctx = None
        cert, key = args.tls_cert, args.tls_key
        if not cert and self.config.tls:
            cert = self.config.resolve(self.config.tls["cert"])
            key = self.config.resolve(self.config.tls.get("key", self.config.tls["cert"]))
        if cert:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(cert, key)
            self.tls_ctx = ctx
        if ":" in args.host:
            self.address_family = socket.AF_INET6
        super().__init__((args.host, args.port), Handler)

    def handle_error(self, request, client_address):
        pass  # client went away mid-request: nothing to report

    def _mtime(self):
        try:
            st = os.stat(self.config_path)
            return st.st_mtime_ns, st.st_size
        except OSError:
            return None

    def maybe_reload(self):
        m = self._mtime()
        if m == self.mtime:
            return
        self.mtime = m
        try:
            self.config = Config(self.config_path)
            self.cycle_pos.clear()
        except (OSError, ConfigError) as e:
            sys.stderr.write(f"reload failed, keeping old config: {e}\n")

    def next_cycle(self, idx, items):
        with self.cycle_lock:
            n = self.cycle_pos.get(idx, 0)
            self.cycle_pos[idx] = n + 1
        return items[n % len(items)]


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="LinuxMissions mock HTTP/1.1 server.")
    p.add_argument("--config", help="routes config (JSON)")
    p.add_argument("--log", help="append an access-log line per request here")
    p.add_argument("--tls-cert", help="PEM certificate (enables HTTPS)")
    p.add_argument("--tls-key", help="PEM private key (default: same file as --tls-cert)")
    p.add_argument("--check", action="store_true", help="only validate the config and report")
    add_common_args(p)
    args = p.parse_args(argv)
    if args.wait_ready:
        return wait_ready(args.wait_ready, args.timeout)
    if not args.config:
        p.error("--config FILE is required")
    if args.tls_cert and not args.tls_key:
        args.tls_key = args.tls_cert
    try:
        if args.check:
            cfg = Config(args.config)
            print(f"OK: {len(cfg.routes)} routes")
            return 0
        srv = Server(args)
    except (OSError, ConfigError, ssl.SSLError, KeyError) as e:
        sys.stderr.write(f"http_server: {e}\n")
        return 2
    if args.port_file:
        write_atomic(args.port_file, f"{srv.server_address[1]}\n")
    if args.daemon:
        daemonize(args.pid_file)
    elif args.pid_file:
        write_atomic(args.pid_file, f"{os.getpid()}\n")
    srv.life = Lifetime(args.idle_timeout, args.max_lifetime)
    Handler.srv = srv
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
