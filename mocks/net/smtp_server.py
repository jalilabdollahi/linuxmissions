#!/usr/bin/env python3
"""LinuxMissions mock SMTP server (python3 stdlib only).

A small Postfix-like SMTP server on 127.0.0.1 that a player can speak to by
hand with bash's /dev/tcp, nc or a script:

    exec 3<>/dev/tcp/127.0.0.1/$PORT; read -r line <&3; echo "$line"
    printf 'HELO me\\r\\n' >&3; read -r line <&3 ...

Supports HELO/EHLO, MAIL FROM, RCPT TO, DATA (dot-unstuffing), RSET, NOOP,
VRFY, QUIT. Logs the whole conversation and one "queued" line per accepted
message; with --spool, saves each message as <queue-id>.eml.

--strict turns on the checks a careful client must pass: no talking before
the greeting or before the previous reply (SMTP synchronization, PIPELINING
not offered) and no bare LF line endings (commands and the final "." must
end in CRLF).

Start (from a level's setup.sh; returns once the server is listening):

    python3 "$NET/smtp_server.py" --hostname mail.corp.example --domain corp.example \
        --port 0 --port-file "$NET/smtp.port" --log "$NET/smtp.log" --spool "$NET/spool" --strict --daemon
"""
from __future__ import annotations

import argparse
import os
import re
import select
import socket
import socketserver
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
# SMTP
# --------------------------------------------------------------------------
ADDR_RE = re.compile(r"^\s*<([^<>\s]*)>(?:\s+.*)?$")


class Closed(Exception):
    pass


class Session(socketserver.BaseRequestHandler):
    srv = None  # set in main()

    def setup(self):
        self.buf = b""
        self.sock: socket.socket = self.request
        self.sock.settimeout(self.srv.args.session_timeout)
        with self.srv.lock:
            self.srv.conn_no += 1
            self.no = self.srv.conn_no
        self.peer = f"{self.client_address[0]}:{self.client_address[1]}"

    def log(self, text: str) -> None:
        self.srv.log.write(f"{now_stamp()} #{self.no} {text}")

    def say(self, text: str) -> None:
        for line in text.split("\n"):
            self.log(f"S: {line}")
        self.sock.sendall(text.replace("\n", "\r\n").encode() + b"\r\n")

    def readline(self) -> tuple[str, bool]:
        """One line without its ending; second value is True if it ended in CRLF."""
        while b"\n" not in self.buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise Closed
            self.buf += chunk
            if len(self.buf) > 1 << 20:
                raise Closed
        line, self.buf = self.buf.split(b"\n", 1)
        crlf = line.endswith(b"\r")
        return line[:-1 if crlf else None].decode("utf-8", "replace"), crlf

    def talked_early(self) -> bool:
        """True if the client sent more before we answered (strict mode only)."""
        if not self.srv.args.strict:
            return False
        if self.buf:
            return True
        r, _, _ = select.select([self.sock], [], [], self.srv.args.sync_window)
        return bool(r)

    def sync_error(self) -> None:
        self.log("sync error: client sent data before reading the previous reply")
        self.say("554 5.5.0 SMTP synchronization error: wait for each reply before sending the next command")
        raise Closed

    def bare_lf(self) -> None:
        self.log("bare LF: line did not end in CRLF")
        self.say("521 5.5.2 Error: bare <LF> received; end every line with <CR><LF>")
        raise Closed

    def handle(self):
        srv, args = self.srv, self.srv.args
        srv.life.touch()
        self.log(f"connect from {self.peer}")
        try:
            if self.talked_early():
                self.log("client talked before the greeting")
                self.sync_error()
            self.say(f"220 {args.hostname} ESMTP Postfix (Ubuntu)")
            self.loop()
        except (Closed, OSError):
            pass
        self.log("disconnect")
        try:
            # Drain what the client already sent, so it reads our last reply
            # instead of a connection reset.
            self.sock.shutdown(socket.SHUT_WR)
            self.sock.settimeout(0.5)
            while self.sock.recv(4096):
                pass
        except OSError:
            pass
        try:
            self.sock.close()
        except OSError:
            pass

    def loop(self):
        srv, args = self.srv, self.srv.args
        helo, sender, rcpts = None, None, []
        while True:
            line, crlf = self.readline()
            srv.life.touch()
            self.log(f"C: {line}")
            if args.strict and not crlf:
                self.bare_lf()
            if self.talked_early():
                self.sync_error()
            verb, _, arg = line.strip().partition(" ")
            verb = verb.upper()
            arg = arg.strip()
            if verb in ("HELO", "EHLO"):
                if not arg:
                    self.say(f"501 Syntax: {verb} hostname")
                    continue
                helo, sender, rcpts = arg, None, []
                if verb == "HELO":
                    self.say(f"250 {args.hostname}")
                else:
                    ext = [] if args.strict else ["PIPELINING"]
                    ext += ["SIZE 10240000", "VRFY", "ENHANCEDSTATUSCODES", "8BITMIME"]
                    self.say("\n".join([f"250-{args.hostname}"] + [f"250-{e}" for e in ext[:-1]] + [f"250 {ext[-1]}"]))
            elif verb == "MAIL":
                m = re.match(r"(?i)^FROM:(.*)$", arg)
                if not helo:
                    self.say("503 5.5.1 Error: send HELO/EHLO first")
                elif sender is not None:
                    self.say("503 5.5.1 Error: nested MAIL command")
                elif not m or not ADDR_RE.match(m.group(1)):
                    self.say("501 5.5.4 Syntax: MAIL FROM:<address>")
                else:
                    sender = ADDR_RE.match(m.group(1)).group(1)
                    self.say("250 2.1.0 Ok")
            elif verb == "RCPT":
                m = re.match(r"(?i)^TO:(.*)$", arg)
                if sender is None:
                    self.say("503 5.5.1 Error: need MAIL command")
                elif not m or not ADDR_RE.match(m.group(1)) or "@" not in ADDR_RE.match(m.group(1)).group(1):
                    self.say("501 5.5.4 Syntax: RCPT TO:<address>")
                else:
                    rcpt = ADDR_RE.match(m.group(1)).group(1)
                    domain = rcpt.rsplit("@", 1)[1].lower()
                    if args.domain and domain not in [d.lower() for d in args.domain]:
                        self.say(f"454 4.7.1 <{rcpt}>: Relay access denied")
                    elif args.mailbox and rcpt.lower() not in [b.lower() for b in args.mailbox]:
                        self.say(f"550 5.1.1 <{rcpt}>: Recipient address rejected: "
                                 "User unknown in local recipient table")
                    else:
                        rcpts.append(rcpt)
                        self.say("250 2.1.5 Ok")
            elif verb == "DATA":
                if sender is None:
                    self.say("503 5.5.1 Error: need MAIL command")
                elif not rcpts:
                    self.say("554 5.5.1 Error: no valid recipients")
                else:
                    self.say("354 End data with <CR><LF>.<CR><LF>")
                    self.data(helo, sender, rcpts)
                    sender, rcpts = None, []
            elif verb == "RSET":
                sender, rcpts = None, []
                self.say("250 2.0.0 Ok")
            elif verb == "NOOP":
                self.say("250 2.0.0 Ok")
            elif verb == "VRFY":
                self.say(f"252 2.0.0 {arg}" if arg else "501 5.5.4 Syntax: VRFY address")
            elif verb == "QUIT":
                self.say("221 2.0.0 Bye")
                raise Closed
            elif verb == "":
                self.say("500 5.5.2 Error: bad syntax")
            else:
                self.say("502 5.5.2 Error: command not recognized")

    def data(self, helo, sender, rcpts):
        srv, args = self.srv, self.srv.args
        lines = []
        while True:
            line, crlf = self.readline()
            if args.strict and not crlf:
                self.log(f"C: {line}")
                self.bare_lf()
            if line == ".":
                self.log(f"C: <{len(lines)} lines of message data>")
                self.log("C: .")
                break
            lines.append(line[1:] if line.startswith("..") else line)
        if self.talked_early():
            self.sync_error()
        qid = os.urandom(5).hex().upper()
        body = "\r\n".join(lines) + "\r\n"
        subject = ""
        for ln in lines:
            if ln == "":
                break
            if ln.lower().startswith("subject:"):
                subject = ln.split(":", 1)[1].strip()
        if args.spool:
            os.makedirs(args.spool, exist_ok=True)
            stamp = time.strftime("%a, %d %b %Y %H:%M:%S %z")
            env = (f"Return-Path: <{sender}>\r\nX-Original-To: {', '.join(rcpts)}\r\n"
                   f"Received: from {helo} (localhost [{self.client_address[0]}])\r\n"
                   f"\tby {args.hostname} (Postfix) with SMTP id {qid}; {stamp}\r\n")
            write_atomic(os.path.join(args.spool, f"{qid}.eml"), env + body)
        subj = subject.replace('"', "'")
        srv.log.write(f"{now_stamp()} #{self.no} queued {qid} from=<{sender}> to=<{','.join(rcpts)}> "
                      f"size={len(body.encode())} subject=\"{subj}\"")
        self.say(f"250 2.0.0 Ok: queued as {qid}")


class Server(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True

    def handle_error(self, request, client_address):
        pass


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="LinuxMissions mock SMTP server.")
    p.add_argument("--hostname", default="mail.example.test", help="name in the greeting and HELO reply")
    p.add_argument("--domain", action="append", default=[],
                   help="accept mail only for this recipient domain (repeatable; default: any)")
    p.add_argument("--mailbox", action="append", default=[],
                   help="accept only these recipient addresses (repeatable; default: any)")
    p.add_argument("--log", help="conversation log (C:/S: lines, queued lines)")
    p.add_argument("--spool", help="directory to save accepted messages as <queue-id>.eml")
    p.add_argument("--strict", action="store_true",
                   help="reject pipelining / talking before the reply, and bare LF line endings")
    p.add_argument("--sync-window", type=float, default=0.3,
                   help="seconds the server waits before each reply to catch early talkers (--strict)")
    p.add_argument("--session-timeout", type=float, default=300, help="drop idle sessions after N seconds")
    add_common_args(p)
    args = p.parse_args(argv)
    if args.wait_ready:
        return wait_ready(args.wait_ready, args.timeout)
    if ":" in args.host:
        Server.address_family = socket.AF_INET6
    try:
        srv = Server((args.host, args.port), Session)
    except OSError as e:
        sys.stderr.write(f"smtp_server: cannot bind {args.host}:{args.port}: {e}\n")
        return 1
    srv.args, srv.lock, srv.conn_no = args, threading.Lock(), 0
    srv.log = LineLog(args.log)
    if args.port_file:
        write_atomic(args.port_file, f"{srv.server_address[1]}\n")
    if args.daemon:
        daemonize(args.pid_file)
    elif args.pid_file:
        write_atomic(args.pid_file, f"{os.getpid()}\n")
    srv.life = Lifetime(args.idle_timeout, args.max_lifetime)
    Session.srv = srv
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
