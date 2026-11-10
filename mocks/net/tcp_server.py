#!/usr/bin/env python3
"""LinuxMissions mock TCP services (python3 stdlib only).

Small TCP listeners on loopback for port-probing and "speak the protocol"
levels (nc -zv, bash /dev/tcp, ss -ltnp):

  line       optional banner, then answers each line from a reply table
             (silent until the client speaks when there is no banner)
  echo       sends every line back
  banner     sends the banner and closes
  silent     accepts and never sends anything
  close      accepts and closes at once (client sees EOF)
  reset      accepts and resets the connection (client sees ECONNRESET)
  blackhole  listens but its accept queue is kept full, so new connections
             time out like a filtered port (Linux)

One listener from the command line:

    python3 "$NET/tcp_server.py" --mode line --reply 'STATUS=OK token=4f2a' \
        --port 0 --port-file "$NET/status.port" --log "$NET/tcp.log" --daemon

or several from a JSON config (--config); see mocks/README.md.
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import sys
import threading
import time

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


def now_stamp() -> str:
    t = time.time()
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(t)) + f".{int(t % 1 * 1000):03d}"


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
# Listeners
# --------------------------------------------------------------------------
MODES = ("line", "echo", "banner", "silent", "close", "reset", "blackhole")
KEYS = {"name", "host", "port", "mode", "banner", "replies", "default_reply", "quit_reply", "crlf", "delay"}


class Listener:
    def __init__(self, spec: dict, log: LineLog, life: Lifetime | None = None):
        bad = set(spec) - KEYS
        if bad:
            raise ValueError(f"unknown listener key(s): {', '.join(sorted(bad))}")
        self.name = spec.get("name")
        self.host = spec.get("host", "127.0.0.1")
        self.mode = spec.get("mode", "line")
        if self.mode not in MODES:
            raise ValueError(f"mode must be one of {', '.join(MODES)}")
        self.banner = spec.get("banner")
        self.replies = {k.upper(): v for k, v in (spec.get("replies") or {}).items()}
        self.default_reply = spec.get("default_reply", "ERR unknown command")
        self.quit_reply = spec.get("quit_reply", "BYE")
        self.eol = b"\r\n" if spec.get("crlf") else b"\n"
        self.delay = float(spec.get("delay", 0))
        self.log, self.life = log, life
        fam = socket.AF_INET6 if ":" in self.host else socket.AF_INET
        self.sock = socket.socket(fam, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((self.host, int(spec.get("port", 0))))
        self.port = self.sock.getsockname()[1]
        self.fillers: list[socket.socket] = []
        if self.mode == "blackhole":
            self.sock.listen(0)
            self.fill_queue()
        else:
            self.sock.listen(64)

    def label(self) -> str:
        return self.name or str(self.port)

    def fill_queue(self) -> None:
        """Keep the accept queue full so new SYNs are dropped (connect times out)."""
        fam = self.sock.family
        target = ("::1" if fam == socket.AF_INET6 else "127.0.0.1") if self.host in ("0.0.0.0", "::") else self.host
        for _ in range(16):
            s = socket.socket(fam, socket.SOCK_STREAM)
            s.settimeout(0.3)
            try:
                s.connect((target, self.port))
            except OSError:
                s.close()
                return
            self.fillers.append(s)

    def send(self, conn, text: str) -> None:
        if self.delay:
            time.sleep(self.delay)
        conn.sendall(text.encode() + self.eol)

    def serve(self) -> None:
        if self.mode == "blackhole":
            return  # never accept
        while True:
            try:
                conn, addr = self.sock.accept()
            except OSError:
                continue
            if self.life:
                self.life.touch()
            threading.Thread(target=self.session, args=(conn, addr), daemon=True).start()

    def session(self, conn: socket.socket, addr) -> None:
        peer = f"{addr[0]}:{addr[1]}"
        who = self.label()
        self.log.write(f"{now_stamp()} {who} {peer} connect")
        try:
            if self.mode == "reset":
                conn.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, b"\1\0\0\0\0\0\0\0")
                self.log.write(f"{now_stamp()} {who} {peer} reset")
                return
            if self.mode == "close":
                return
            conn.settimeout(600)
            if self.banner is not None:
                self.send(conn, self.banner)
                self.log.write(f"{now_stamp()} {who} {peer} S: {self.banner}")
                if self.mode == "banner":
                    return
            buf = b""
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                if self.life:
                    self.life.touch()
                buf += chunk
                while b"\n" in buf:
                    raw, buf = buf.split(b"\n", 1)
                    line = raw.rstrip(b"\r").decode("utf-8", "replace")
                    self.log.write(f"{now_stamp()} {who} {peer} C: {line}")
                    if self.mode == "silent":
                        continue
                    if self.mode == "echo":
                        reply = line
                    else:
                        cmd = line.strip().upper()
                        if cmd in self.replies:
                            reply = self.replies[cmd]
                        elif cmd.split(" ")[0] in self.replies:
                            reply = self.replies[cmd.split(" ")[0]]
                        elif cmd == "QUIT":
                            self.send(conn, self.quit_reply)
                            self.log.write(f"{now_stamp()} {who} {peer} S: {self.quit_reply}")
                            return
                        else:
                            reply = self.default_reply
                    self.send(conn, reply)
                    self.log.write(f"{now_stamp()} {who} {peer} S: {reply}")
        except OSError:
            pass
        finally:
            self.log.write(f"{now_stamp()} {who} {peer} disconnect")
            try:
                conn.close()
            except OSError:
                pass


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="LinuxMissions mock TCP services.")
    p.add_argument("--config", help="JSON file with {\"listeners\": [...]} (several listeners)")
    p.add_argument("--mode", choices=MODES, default="line", help="single listener mode (default line)")
    p.add_argument("--banner", help="line sent when a client connects")
    p.add_argument("--reply", action="append", default=[], metavar="CMD=TEXT",
                   help="line mode: answer CMD (case-insensitive) with TEXT (repeatable)")
    p.add_argument("--default-reply", default="ERR unknown command", help="line mode: answer to anything else")
    p.add_argument("--crlf", action="store_true", help="end server lines with CRLF instead of LF")
    p.add_argument("--delay", type=float, default=0, help="seconds to wait before each reply")
    p.add_argument("--name", help="label for the log")
    p.add_argument("--log", help="connection log (connect / C: / S: / disconnect lines)")
    add_common_args(p)
    args = p.parse_args(argv)
    if args.wait_ready:
        return wait_ready(args.wait_ready, args.timeout)
    log = LineLog(args.log)
    try:
        if args.config:
            with open(args.config, encoding="utf-8") as f:
                specs = json.load(f).get("listeners", [])
            if not specs:
                raise ValueError("config has no listeners")
        else:
            replies = {}
            for item in args.reply:
                if "=" not in item:
                    raise ValueError(f"--reply needs CMD=TEXT, got {item!r}")
                k, v = item.split("=", 1)
                replies[k] = v
            specs = [{"name": args.name, "host": args.host, "port": args.port, "mode": args.mode,
                      "banner": args.banner, "replies": replies, "default_reply": args.default_reply,
                      "crlf": args.crlf, "delay": args.delay}]
        listeners = [Listener(s, log) for s in specs]
    except (OSError, ValueError, json.JSONDecodeError) as e:
        sys.stderr.write(f"tcp_server: {e}\n")
        return 1
    if args.port_file:
        if args.config:
            text = "".join(f"{lst.name or lst.port} {lst.port}\n" for lst in listeners)
        else:
            text = f"{listeners[0].port}\n"
        write_atomic(args.port_file, text)
    if args.daemon:
        daemonize(args.pid_file)
    elif args.pid_file:
        write_atomic(args.pid_file, f"{os.getpid()}\n")
    life = Lifetime(args.idle_timeout, args.max_lifetime)
    for lst in listeners:
        lst.life = life
        threading.Thread(target=lst.serve, daemon=True).start()
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    sys.exit(main())
