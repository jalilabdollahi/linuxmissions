#!/usr/bin/env python3
"""LinuxMissions mock DNS server (python3 stdlib only).

Serves zone data from BIND-style zone files on 127.0.0.1 over UDP and TCP,
so the real dig / nslookup / host can query it:

    dig @127.0.0.1 -p PORT shop.example MX +short
    nslookup -port=PORT shop.example 127.0.0.1
    host -p PORT 10.0.0.5 127.0.0.1

Start (from a level's setup.sh; returns once the server is listening):

    python3 "$NET/dns_server.py" --zone "$NET/zone.db" --port 0 \
        --port-file "$NET/dns.port" --log "$NET/query.log" --daemon

See mocks/README.md for the zone format, the --rules knobs (nxdomain,
servfail, refused, nodata, drop, truncate, delay=S, type=T) and the log format.
"""
from __future__ import annotations

import argparse
import ipaddress
import os
import re
import select
import socket
import struct
import sys
import threading
import time

TYPES = {"A": 1, "NS": 2, "CNAME": 5, "SOA": 6, "PTR": 12, "MX": 15, "TXT": 16,
         "AAAA": 28, "SRV": 33, "OPT": 41, "ANY": 255}
TYPE_NAMES = {v: k for k, v in TYPES.items()}
RCODES = {"NOERROR": 0, "FORMERR": 1, "SERVFAIL": 2, "NXDOMAIN": 3, "NOTIMP": 4, "REFUSED": 5}
RCODE_NAMES = {v: k for k, v in RCODES.items()}
ROOT_SOA = ("a.root-servers.net.", "nstld.verisign-grs.com.", 2026111000, 1800, 900, 604800, 86400)


def type_name(t: int) -> str:
    return TYPE_NAMES.get(t, f"TYPE{t}")


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
# Zone files
# --------------------------------------------------------------------------
class ZoneError(Exception):
    pass


class Quoted(str):
    """A token that was written in double quotes."""


def logical_lines(text: str, fname: str):
    """Yield (lineno, owner_blank, tokens) with comments, quotes and (...) handled."""
    depth = 0
    cur: list = []
    owner_blank = False
    start = 0
    for lineno, raw in enumerate(text.splitlines(), 1):
        if depth == 0:
            cur, owner_blank, start = [], raw[:1] in (" ", "\t"), lineno
        i, n = 0, len(raw)
        while i < n:
            c = raw[i]
            if c == ";":
                break
            if c in " \t\r":
                i += 1
            elif c == "(":
                depth += 1
                i += 1
            elif c == ")":
                depth -= 1
                if depth < 0:
                    raise ZoneError(f"{fname}:{lineno}: unbalanced ')'")
                i += 1
            elif c == '"':
                j, buf = i + 1, []
                while j < n and raw[j] != '"':
                    if raw[j] == "\\" and j + 1 < n:
                        if raw[j + 1:j + 4].isdigit() and len(raw[j + 1:j + 4]) == 3:
                            buf.append(chr(int(raw[j + 1:j + 4])))
                            j += 4
                        else:
                            buf.append(raw[j + 1])
                            j += 2
                        continue
                    buf.append(raw[j])
                    j += 1
                if j >= n:
                    raise ZoneError(f"{fname}:{lineno}: unterminated quoted string")
                cur.append(Quoted("".join(buf)))
                i = j + 1
            else:
                j = i
                while j < n and raw[j] not in ' \t\r;()"':
                    j += 1
                cur.append(raw[i:j])
                i = j
        if depth == 0 and cur:
            yield start, owner_blank, cur
    if depth:
        raise ZoneError(f"{fname}: unbalanced '(' at end of file")


TTL_UNITS = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}


def parse_ttl(tok: str) -> int | None:
    if tok.isdigit():
        return int(tok)
    if re.fullmatch(r"(\d+[smhdwSMHDW])+", tok):
        return sum(int(n) * TTL_UNITS[u.lower()] for n, u in re.findall(r"(\d+)([a-zA-Z])", tok))
    return None


def absolute(name: str, origin: str) -> str:
    name = name.lower()
    if name == "@":
        return origin
    if name.endswith("."):
        return name
    return name + "." + origin if origin != "." else name + "."


def in_zone(name: str, apex: str) -> bool:
    return apex == "." or name == apex or name.endswith("." + apex)


class Record:
    __slots__ = ("owner", "rtype", "ttl", "data")

    def __init__(self, owner, rtype, ttl, data):
        self.owner, self.rtype, self.ttl, self.data = owner, rtype, ttl, data


class ZoneData:
    def __init__(self):
        self.nodes: dict[str, list[Record]] = {}
        self.soa: dict[str, Record] = {}

    def add(self, rec: Record, where: str) -> None:
        rrs = self.nodes.setdefault(rec.owner, [])
        if rec.rtype == "CNAME" and any(r.rtype != "CNAME" for r in rrs) or \
                rec.rtype != "CNAME" and any(r.rtype == "CNAME" for r in rrs):
            raise ZoneError(f"{where}: {rec.owner} has CNAME and other data")
        if rec.rtype == "CNAME" and rrs:
            raise ZoneError(f"{where}: {rec.owner} has more than one CNAME")
        if rec.rtype == "SOA":
            if rec.owner in self.soa:
                raise ZoneError(f"{where}: second SOA for {rec.owner}")
            self.soa[rec.owner] = rec
        if not any(r.rtype == rec.rtype and r.data == rec.data for r in rrs):
            rrs.append(rec)

    def load(self, path: str) -> None:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        origin, default_ttl, last_owner = ".", 3600, None
        for lineno, blank, toks in logical_lines(text, path):
            where = f"{path}:{lineno}"
            if toks[0].startswith("$"):
                d = toks[0].upper()
                if d == "$ORIGIN" and len(toks) == 2:
                    origin = absolute(toks[1], ".")
                elif d == "$TTL" and len(toks) == 2 and parse_ttl(toks[1]) is not None:
                    default_ttl = parse_ttl(toks[1])
                else:
                    raise ZoneError(f"{where}: unsupported directive {' '.join(toks)}")
                continue
            if blank:
                if last_owner is None:
                    raise ZoneError(f"{where}: record without an owner name")
                owner = last_owner
            else:
                owner = absolute(toks.pop(0), origin)
            last_owner = owner
            ttl = None
            while toks and (toks[0].upper() == "IN" or (ttl is None and parse_ttl(toks[0]) is not None)):
                tok = toks.pop(0)
                if tok.upper() != "IN":
                    ttl = parse_ttl(tok)
            if not toks:
                raise ZoneError(f"{where}: missing record type")
            rtype = toks.pop(0).upper()
            self.add(Record(owner, rtype, default_ttl if ttl is None else ttl,
                            self.parse_rdata(rtype, toks, origin, where)), where)

    @staticmethod
    def parse_rdata(rtype: str, t: list, origin: str, where: str):
        def need(n):
            if len(t) != n:
                raise ZoneError(f"{where}: {rtype} needs {n} value(s), got {len(t)}")

        def num(tok, bits=16):
            if not tok.isdigit() or int(tok) >= 1 << bits:
                raise ZoneError(f"{where}: bad number {tok!r} in {rtype}")
            return int(tok)
        try:
            if rtype == "A":
                need(1)
                return str(ipaddress.IPv4Address(t[0]))
            if rtype == "AAAA":
                need(1)
                return str(ipaddress.IPv6Address(t[0]))
        except ValueError as e:
            raise ZoneError(f"{where}: {e}") from None
        if rtype in ("CNAME", "NS", "PTR"):
            need(1)
            return absolute(t[0], origin)
        if rtype == "MX":
            need(2)
            return (num(t[0]), absolute(t[1], origin))
        if rtype == "SRV":
            need(4)
            return (num(t[0]), num(t[1]), num(t[2]), absolute(t[3], origin))
        if rtype == "TXT":
            if not t:
                raise ZoneError(f"{where}: TXT needs at least one string")
            out = []
            for s in t:
                b = s.encode("latin-1", "replace")
                out.extend(b[i:i + 255].decode("latin-1") for i in range(0, max(len(b), 1), 255))
            return tuple(out)
        if rtype == "SOA":
            need(7)
            vals = [parse_ttl(x) for x in t[2:]]
            if None in vals:
                raise ZoneError(f"{where}: bad SOA timer values")
            return (absolute(t[0], origin), absolute(t[1], origin), *vals)
        raise ZoneError(f"{where}: unsupported record type {rtype}")

    def zone_of(self, name: str) -> str | None:
        best = None
        for apex in self.soa:
            if in_zone(name, apex) and (best is None or len(apex) > len(best)):
                best = apex
        return best

    def node_exists(self, name: str) -> bool:
        if name in self.nodes:
            return True
        suffix = "." + name
        return any(o.endswith(suffix) for o in self.nodes)  # empty non-terminal

    def lookup(self, name: str, apex: str | None) -> tuple[bool, list[Record]]:
        """Records at `name` (wildcards synthesised); (exists, records)."""
        if name in self.nodes:
            return True, self.nodes[name]
        if self.node_exists(name):
            return True, []
        labels = name.split(".")
        for i in range(1, len(labels) - 1):
            parent = ".".join(labels[i:])
            if apex and not in_zone(parent, apex):
                break
            wild = "*." + parent
            if wild in self.nodes:
                return True, [Record(name, r.rtype, r.ttl, r.data) for r in self.nodes[wild]]
            if self.node_exists(parent):
                break
        return False, []


# --------------------------------------------------------------------------
# Behaviour rules
# --------------------------------------------------------------------------
class Rule:
    def __init__(self, pattern: str, qtype: str | None, rcode: str | None, drop: bool,
                 truncate: bool, delay: float):
        self.pattern, self.qtype, self.rcode = pattern, qtype, rcode
        self.drop, self.truncate, self.delay = drop, truncate, delay

    def matches(self, qname: str, qtype: str) -> bool:
        if self.qtype and self.qtype != qtype:
            return False
        p = self.pattern
        if p == "*":
            return True
        if p.startswith("*."):
            return qname.endswith(p[1:])
        if p.startswith("."):
            return qname == p[1:] or qname.endswith(p)
        return qname == p


def load_rules(path: str) -> list[Rule]:
    rules = []
    with open(path, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            toks = line.split("#", 1)[0].split()
            if not toks:
                continue
            pat = toks[0].lower()
            if pat != "*" and not pat.endswith("."):
                pat += "."
            qtype, rcode, drop, trunc, delay = None, None, False, False, 0.0
            for tok in toks[1:]:
                low = tok.lower()
                if low in ("nxdomain", "servfail", "refused", "formerr", "notimp"):
                    rcode = low.upper()
                elif low == "nodata":
                    rcode = "NODATA"
                elif low == "drop":
                    drop = True
                elif low in ("truncate", "tc"):
                    trunc = True
                elif low.startswith("delay="):
                    try:
                        delay = float(low[6:])
                    except ValueError:
                        raise ZoneError(f"{path}:{lineno}: bad delay {tok!r}") from None
                elif low.startswith("type="):
                    qtype = tok[5:].upper()
                else:
                    raise ZoneError(f"{path}:{lineno}: unknown rule action {tok!r}")
            rules.append(Rule(pat, qtype, rcode, drop, trunc, delay))
    return rules


# --------------------------------------------------------------------------
# Wire format
# --------------------------------------------------------------------------
class FormErr(Exception):
    pass


def read_name(data: bytes, off: int) -> tuple[str, int]:
    labels, jumped, end, hops = [], False, off, 0
    while True:
        if off >= len(data):
            raise FormErr("name past end")
        ln = data[off]
        if ln & 0xC0 == 0xC0:
            if off + 1 >= len(data) or hops > 20:
                raise FormErr("bad pointer")
            ptr = ((ln & 0x3F) << 8) | data[off + 1]
            if not jumped:
                end = off + 2
            jumped, off, hops = True, ptr, hops + 1
            continue
        if ln == 0:
            if not jumped:
                end = off + 1
            break
        labels.append(data[off + 1:off + 1 + ln].decode("latin-1"))
        off += 1 + ln
    return (".".join(labels) + ".") if labels else ".", end


class Query:
    def __init__(self, data: bytes):
        if len(data) < 12:
            raise FormErr("short header")
        self.id, self.flags, qd, an, ns, ar = struct.unpack("!6H", data[:12])
        self.opcode = (self.flags >> 11) & 0xF
        if qd != 1:
            raise FormErr("qdcount != 1")
        self.qname, off = read_name(data, 12)
        if off + 4 > len(data):
            raise FormErr("short question")
        self.qtype, self.qclass = struct.unpack("!HH", data[off:off + 4])
        self.question = data[12:off + 4]
        off += 4
        self.edns, self.udp_size, self.cookie = False, 512, None
        for _ in range(an + ns + ar):
            _, off = read_name(data, off)
            if off + 10 > len(data):
                raise FormErr("short rr")
            rtype, rclass, _ttl, rdlen = struct.unpack("!HHIH", data[off:off + 10])
            off += 10
            rdata = data[off:off + rdlen]
            off += rdlen
            if rtype == 41:
                self.edns, self.udp_size = True, max(512, rclass)
                o = 0
                while o + 4 <= len(rdata):
                    code, olen = struct.unpack("!HH", rdata[o:o + 4])
                    if code == 10 and olen >= 8:
                        self.cookie = rdata[o + 4:o + 12]
                    o += 4 + olen


class Writer:
    def __init__(self):
        self.buf = bytearray()
        self.comp: dict[str, int] = {}

    def name(self, name: str, compress: bool = True) -> None:
        labels = [] if name == "." else name.rstrip(".").split(".")
        for i in range(len(labels)):
            key = ".".join(labels[i:]).lower()
            if compress and key in self.comp:
                self.buf += struct.pack("!H", 0xC000 | self.comp[key])
                return
            if len(self.buf) < 0x3FFF:
                self.comp.setdefault(key, len(self.buf))
            lab = labels[i].encode("latin-1")
            self.buf.append(len(lab))
            self.buf += lab
        self.buf.append(0)

    def rr(self, rec: Record, owner: str | None = None) -> None:
        self.name(owner or rec.owner)
        self.buf += struct.pack("!HHI", TYPES[rec.rtype], 1, rec.ttl)
        at = len(self.buf)
        self.buf += b"\0\0"
        d, t = rec.data, rec.rtype
        if t == "A":
            self.buf += ipaddress.IPv4Address(d).packed
        elif t == "AAAA":
            self.buf += ipaddress.IPv6Address(d).packed
        elif t in ("CNAME", "NS", "PTR"):
            self.name(d)
        elif t == "MX":
            self.buf += struct.pack("!H", d[0])
            self.name(d[1])
        elif t == "SRV":
            self.buf += struct.pack("!HHH", d[0], d[1], d[2])
            self.name(d[3], compress=False)
        elif t == "TXT":
            for s in d:
                b = s.encode("latin-1")
                self.buf.append(len(b))
                self.buf += b
        elif t == "SOA":
            self.name(d[0])
            self.name(d[1])
            self.buf += struct.pack("!5I", *d[2:])
        struct.pack_into("!H", self.buf, at, len(self.buf) - at - 2)


# --------------------------------------------------------------------------
# Server
# --------------------------------------------------------------------------
class DNSServer:
    def __init__(self, args):
        self.args = args
        self.recursive = args.mode == "resolver"
        self.log = LineLog(args.log)
        self.lock = threading.Lock()
        self.sources = list(args.zone) + ([args.rules] if args.rules else [])
        self.mtimes = None
        self.server_cookie = os.urandom(8)
        self.zones, self.rules = self.load()

    def load(self):
        zd = ZoneData()
        for path in self.args.zone:
            zd.load(path)
        rules = load_rules(self.args.rules) if self.args.rules else []
        self.mtimes = self._mtimes()
        return zd, rules

    def _mtimes(self):
        out = []
        for p in self.sources:
            try:
                st = os.stat(p)
                out.append((st.st_mtime_ns, st.st_size))
            except OSError:
                out.append(None)
        return out

    def maybe_reload(self) -> None:
        if self._mtimes() == self.mtimes:
            return
        with self.lock:
            try:
                self.zones, self.rules = self.load()
            except (OSError, ZoneError) as e:
                self.mtimes = self._mtimes()
                sys.stderr.write(f"reload failed, keeping old data: {e}\n")

    # -- answer building ------------------------------------------------
    def resolve(self, qname: str, qtype: int):
        """Return (rcode, answers, authority, additional, authoritative)."""
        zd = self.zones
        qt = type_name(qtype)
        apex = zd.zone_of(qname)
        if apex is None and not self.recursive and not zd.node_exists(qname) and \
                not zd.lookup(qname, None)[0]:
            return RCODES["REFUSED"], [], [], [], False
        answers: list[tuple[str, Record]] = []
        authority: list[Record] = []
        rcode, aa, name, seen = 0, True, qname, set()
        for _ in range(16):
            apex = zd.zone_of(name)
            exists, rrs = zd.lookup(name, apex)
            if not exists:
                if apex is None and answers and not self.recursive:
                    break  # CNAME target outside our data: return the chain only
                rcode = RCODES["NXDOMAIN"]
                authority.append(self.soa_for(apex))
                break
            if qt == "ANY":
                answers += [(name, r) for r in rrs]
                break
            cn = [r for r in rrs if r.rtype == "CNAME"]
            if cn and qt != "CNAME":
                answers.append((name, cn[0]))
                seen.add(name)
                name = cn[0].data
                if name in seen:
                    if self.recursive:
                        return RCODES["SERVFAIL"], [], [], [], False
                    break
                continue
            match = [r for r in rrs if r.rtype == qt]
            if match:
                answers += [(name, r) for r in match]  # zone-file order, deterministic
            else:
                authority.append(self.soa_for(apex))
            break
        else:
            return RCODES["SERVFAIL"], [], [], [], False
        additional = []
        have = {(o, r.rtype, r.data) for o, r in answers}
        for _o, r in answers:
            target = r.data[1] if r.rtype == "MX" else r.data[3] if r.rtype == "SRV" else \
                r.data if r.rtype == "NS" else None
            if target and target in zd.nodes:
                for g in zd.nodes[target]:
                    if g.rtype in ("A", "AAAA") and (target, g.rtype, g.data) not in have:
                        additional.append(g)
                        have.add((target, g.rtype, g.data))
        return rcode, answers, authority, additional, aa and not self.recursive

    def soa_for(self, apex: str | None) -> Record:
        if apex and apex in self.zones.soa:
            soa = self.zones.soa[apex]
            return Record(soa.owner, "SOA", min(soa.ttl, soa.data[6]), soa.data)
        return Record(".", "SOA", 86400, ROOT_SOA)

    def build(self, q: Query, rcode: int, answers=(), authority=(), additional=(),
              aa=False, tc=False) -> bytes:
        w = Writer()
        flags = 0x8000 | (q.flags & 0x7800) | (q.flags & 0x0100) | (q.flags & 0x0010)
        if aa:
            flags |= 0x0400
        if tc:
            flags |= 0x0200
        if self.recursive:
            flags |= 0x0080
        flags |= rcode & 0xF
        ar = len(additional) + (1 if q.edns else 0)
        w.buf += struct.pack("!6H", q.id, flags, 1, len(answers), len(authority), ar)
        w.name(q.qname)
        w.buf += struct.pack("!HH", q.qtype, q.qclass)
        for owner, r in answers:
            w.rr(r, owner)
        for r in authority:
            w.rr(r)
        for r in additional:
            w.rr(r)
        if q.edns:
            opts = b""
            if q.cookie:
                opts = struct.pack("!HH", 10, 16) + q.cookie + self.server_cookie
            w.buf += b"\0" + struct.pack("!HHIH", 41, 1232, 0, len(opts)) + opts
        return bytes(w.buf)

    def handle(self, data: bytes, client, proto: str):
        """Return (response bytes or None, delay seconds)."""
        self.maybe_reload()
        who = f"{client[0]}#{client[1]}"
        try:
            q = Query(data)
        except (FormErr, UnicodeDecodeError, struct.error, IndexError):
            if len(data) >= 12:
                qid, flags = struct.unpack("!HH", data[:4])
                resp = struct.pack("!6H", qid, 0x8000 | (flags & 0x7900) | 1, 0, 0, 0, 0)
                self.log.write(f"{now_stamp()} {who} {proto} - - FORMERR 0 -")
                return resp, 0
            return None, 0
        qname = q.qname.lower()
        qt = type_name(q.qtype)
        notes = []
        if q.opcode != 0:
            self.log.write(f"{now_stamp()} {who} {proto} {qname} {qt} NOTIMP 0 -")
            return self.build(q, RCODES["NOTIMP"]), 0
        rule = next((r for r in self.rules if r.matches(qname, qt)), None)
        delay = rule.delay if rule else 0.0
        if delay:
            notes.append(f"delay={delay:g}")
        if rule and rule.drop:
            self.log.write(f"{now_stamp()} {who} {proto} {qname} {qt} DROPPED 0 -")
            return None, 0
        if q.qclass not in (1, 255):
            rcode, ans, auth, add, aa = RCODES["REFUSED"], [], [], [], False
        elif rule and rule.rcode == "NODATA":
            apex = self.zones.zone_of(qname)
            rcode, ans, auth, add, aa = 0, [], [self.soa_for(apex)], [], not self.recursive
        elif rule and rule.rcode:
            rcode, ans, auth, add, aa = RCODES[rule.rcode], [], [], [], False
            if rule.rcode == "NXDOMAIN":
                auth, aa = [self.soa_for(self.zones.zone_of(qname))], not self.recursive
        else:
            rcode, ans, auth, add, aa = self.resolve(qname, q.qtype)
        resp = self.build(q, rcode, ans, auth, add, aa)
        limit = q.udp_size if q.edns else 512
        if proto == "udp" and ((rule and rule.truncate) or len(resp) > limit):
            resp = self.build(q, rcode, aa=aa, tc=True)
            notes.append("tc")
        self.log.write(f"{now_stamp()} {who} {proto} {qname} {qt} {RCODE_NAMES.get(rcode, rcode)} "
                       f"{len(ans)} {','.join(notes) or '-'}")
        return resp, delay


def serve(args) -> int:
    try:
        srv = DNSServer(args)
    except (OSError, ZoneError) as e:
        sys.stderr.write(f"dns_server: {e}\n")
        return 2
    if args.check:
        n = sum(len(v) for v in srv.zones.nodes.values())
        print(f"OK: {n} records, zones: {' '.join(sorted(srv.zones.soa)) or '(none)'}, {len(srv.rules)} rules")
        return 0
    fam = socket.AF_INET6 if ":" in args.host else socket.AF_INET
    for _ in range(50):
        udp = socket.socket(fam, socket.SOCK_DGRAM)
        tcp = socket.socket(fam, socket.SOCK_STREAM)
        tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            udp.bind((args.host, args.port))
            port = udp.getsockname()[1]
            tcp.bind((args.host, port))
            tcp.listen(64)
            break
        except OSError as e:
            udp.close()
            tcp.close()
            if args.port:
                sys.stderr.write(f"dns_server: cannot bind {args.host}:{args.port}: {e}\n")
                return 1
    else:
        sys.stderr.write("dns_server: no free port with both UDP and TCP\n")
        return 1
    if args.port_file:
        write_atomic(args.port_file, f"{port}\n")
    if args.daemon:
        daemonize(args.pid_file)
    elif args.pid_file:
        write_atomic(args.pid_file, f"{os.getpid()}\n")
    life = Lifetime(args.idle_timeout, args.max_lifetime)

    def reply_udp(resp, addr, delay):
        if delay:
            time.sleep(delay)
        try:
            udp.sendto(resp, addr)
        except OSError:
            pass

    def tcp_conn(conn, addr):
        conn.settimeout(30)
        try:
            while True:
                hdr = recv_exact(conn, 2)
                if not hdr:
                    return
                msg = recv_exact(conn, struct.unpack("!H", hdr)[0])
                if msg is None:
                    return
                life.touch()
                resp, delay = srv.handle(msg, addr, "tcp")
                if resp is None:
                    time.sleep(30)  # silent drop: hold the connection, send nothing
                    return
                if delay:
                    time.sleep(delay)
                conn.sendall(struct.pack("!H", len(resp)) + resp)
        except OSError:
            pass
        finally:
            conn.close()

    while True:
        ready, _, _ = select.select([udp, tcp], [], [])
        if udp in ready:
            try:
                data, addr = udp.recvfrom(65535)
            except OSError:
                continue
            life.touch()
            resp, delay = srv.handle(data, addr, "udp")
            if resp is not None:
                if delay:
                    threading.Thread(target=reply_udp, args=(resp, addr, delay), daemon=True).start()
                else:
                    reply_udp(resp, addr, 0)
        if tcp in ready:
            try:
                conn, addr = tcp.accept()
            except OSError:
                continue
            life.touch()
            threading.Thread(target=tcp_conn, args=(conn, addr), daemon=True).start()


def recv_exact(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="LinuxMissions mock DNS server (UDP+TCP).")
    p.add_argument("--zone", action="append", default=[], help="zone file (repeatable)")
    p.add_argument("--rules", help="behaviour rules file (nxdomain/servfail/refused/nodata/drop/truncate/delay=S)")
    p.add_argument("--log", help="append one line per query here")
    p.add_argument("--mode", choices=("resolver", "auth"), default="resolver",
                   help="resolver: RA set, no AA (default); auth: AA set, REFUSED outside its zones")
    p.add_argument("--check", action="store_true", help="only parse the zone/rules files and report")
    add_common_args(p)
    args = p.parse_args(argv)
    if args.wait_ready:
        return wait_ready(args.wait_ready, args.timeout)
    if not args.zone:
        p.error("at least one --zone FILE is required")
    return serve(args)


if __name__ == "__main__":
    sys.exit(main())
