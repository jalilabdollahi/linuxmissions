"""Unit tests for the shared network mocks in mocks/net/.

Each test starts a server on a random loopback port and talks to it, with a
small stdlib client and, when installed, the real dig / nslookup / host /
curl / wget / openssl (those assertions are skipped with a message when the
tool is missing, e.g. on macOS without wget).

Run: python3 -m unittest tests.test_mocks_net -v   (or scripts/test-levels-docker.sh --unit)
"""
from __future__ import annotations

import base64
import http.client
import importlib.util
import os
import shutil
import signal
import socket
import ssl
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
NET = REPO / "mocks" / "net"
PY = sys.executable


def load(name):
    spec = importlib.util.spec_from_file_location(f"mock_{name}", NET / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


dnsmod = load("dns_server")


def need(tool):
    path = shutil.which(tool)
    if not path:
        raise unittest.SkipTest(f"{tool} not installed here; real-client check skipped (it runs in the Docker image)")
    return path


def run(cmd, timeout=20, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kw)


class ServerCase(unittest.TestCase):
    """Starts mock servers in a temp dir and stops them afterwards."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="lm-mocknet-"))
        self.procs = []

    def tearDown(self):
        for p in self.procs:
            if p.poll() is None:
                p.kill()
            p.wait()
            p.stderr.close()
        for pidf in self.tmp.glob("*.pid"):
            try:
                os.kill(int(pidf.read_text()), signal.SIGKILL)
            except (ValueError, OSError):
                pass
        shutil.rmtree(self.tmp, ignore_errors=True)

    def start(self, script, *args, port_file="srv.port"):
        pf = self.tmp / port_file
        p = subprocess.Popen([PY, str(NET / script), *map(str, args), "--port", "0", "--port-file", str(pf)],
                             stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.procs.append(p)
        end = time.time() + 10
        while time.time() < end:
            if pf.exists() and pf.read_text().strip():
                return pf.read_text().strip()
            if p.poll() is not None:
                self.fail(f"{script} exited: {p.stderr.read().decode()}")
            time.sleep(0.05)
        self.fail(f"{script} did not write its port file")


# --------------------------------------------------------------------------
# DNS
# --------------------------------------------------------------------------
ZONE = r"""
$ORIGIN shop.example.
$TTL 300
@       IN SOA ns1 hostmaster (
              2026111001 ; serial
              3600 600 86400 120 )
@          NS    ns1
ns1        A     127.0.0.1
@          MX    20 backup
@          MX    10 primary
primary 60 CNAME relay
relay      CNAME mx-a.hosting.example.
backup     A     10.0.0.26
www        A     10.0.0.5
www        A     10.0.0.6
www        AAAA  2001:db8::5
@          TXT   "v=spf1 mx -all"
_sip._tcp  SRV   10 60 5060 sip
sip        A     10.0.0.7
*.dyn      A     10.0.0.99
a.b.deep   A     10.0.0.1
loop1      CNAME loop2
loop2      CNAME loop1
$ORIGIN hosting.example.
mx-a       A     10.9.8.7
5.0.0.10.in-addr.arpa. PTR www.shop.example.
"""
BIG_TXT = " ".join('"' + c * 250 + '"' for c in "abcdefg")

RULES = """
# pattern  actions
.broken.example.   servfail
gone.shop.example  nxdomain
blocked.example.   refused
dead.shop.example  drop
www.shop.example   drop type=AAAA
slow.shop.example  delay=1.2
tc.shop.example    truncate
"""


def dns_query(port, name, qtype="A", proto="udp", timeout=2.0, edns=True):
    """Tiny stdlib DNS client: returns dict(rcode, flags, an, answers) or None on timeout."""
    qid = int.from_bytes(os.urandom(2), "big")
    msg = struct.pack("!6H", qid, 0x0100, 1, 0, 0, 1 if edns else 0)
    for label in name.rstrip(".").split("."):
        msg += bytes([len(label)]) + label.encode()
    msg += b"\0" + struct.pack("!HH", dnsmod.TYPES[qtype], 1)
    if edns:
        msg += b"\0" + struct.pack("!HHIH", 41, 1232, 0, 0)
    if proto == "udp":
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(timeout)
    else:
        s = socket.create_connection(("127.0.0.1", port), timeout=timeout)
    try:
        if proto == "udp":
            s.sendto(msg, ("127.0.0.1", port))
            data = s.recv(65535)
        else:
            s.sendall(struct.pack("!H", len(msg)) + msg)
            ln = struct.unpack("!H", s.recv(2))[0]
            data = b""
            while len(data) < ln:
                data += s.recv(ln - len(data))
    except (socket.timeout, TimeoutError):
        return None
    finally:
        s.close()
    rid, flags, qd, an, ns, ar = struct.unpack("!6H", data[:12])
    assert rid == qid
    off = 12
    _, off = dnsmod.read_name(data, off)
    off += 4
    answers = []
    for _ in range(an):
        owner, off = dnsmod.read_name(data, off)
        rtype, _c, ttl, rdlen = struct.unpack("!HHIH", data[off:off + 10])
        off += 10
        rdata = data[off:off + rdlen]
        if rtype == 1:
            val = socket.inet_ntoa(rdata)
        elif rtype in (5, 12, 2):
            val = dnsmod.read_name(data, off)[0]
        elif rtype == 15:
            val = (struct.unpack("!H", rdata[:2])[0], dnsmod.read_name(data, off + 2)[0])
        else:
            val = rdata
        answers.append((owner, dnsmod.type_name(rtype), ttl, val))
        off += rdlen
    return {"rcode": flags & 0xF, "flags": flags, "an": an, "ns": ns, "answers": answers,
            "tc": bool(flags & 0x0200), "aa": bool(flags & 0x0400), "ra": bool(flags & 0x0080)}


class DNSServerTests(ServerCase):
    def setUp(self):
        super().setUp()
        (self.tmp / "zone.db").write_text(ZONE + f"big.shop.example. TXT {BIG_TXT}\n")
        (self.tmp / "rules").write_text(RULES)
        self.log = self.tmp / "query.log"
        self.port = int(self.start("dns_server.py", "--zone", self.tmp / "zone.db", "--rules", self.tmp / "rules",
                                   "--log", self.log))

    def q(self, *a, **kw):
        return dns_query(self.port, *a, **kw)

    def test_a_and_cname_chain(self):
        r = self.q("www.shop.example")
        self.assertEqual(r["rcode"], 0)
        self.assertEqual([a[3] for a in r["answers"]], ["10.0.0.5", "10.0.0.6"])
        self.assertTrue(r["ra"])
        self.assertFalse(r["aa"])
        r = self.q("primary.shop.example")
        self.assertEqual([(a[1], a[3]) for a in r["answers"]],
                         [("CNAME", "relay.shop.example."), ("CNAME", "mx-a.hosting.example."), ("A", "10.9.8.7")])
        self.assertEqual(r["answers"][0][2], 60)

    def test_mx_wildcard_ptr_and_empty_nonterminal(self):
        r = self.q("shop.example", "MX")
        self.assertEqual(sorted(a[3] for a in r["answers"]),
                         [(10, "primary.shop.example."), (20, "backup.shop.example.")])
        self.assertEqual(self.q("host1.dyn.shop.example")["answers"][0][3], "10.0.0.99")
        self.assertEqual(self.q("5.0.0.10.in-addr.arpa", "PTR")["answers"][0][3], "www.shop.example.")
        r = self.q("b.deep.shop.example")
        self.assertEqual((r["rcode"], r["an"]), (0, 0))  # exists, no data
        self.assertEqual(self.q("nothing.shop.example")["rcode"], 3)
        self.assertEqual(self.q("loop1.shop.example")["rcode"], 2)  # CNAME loop -> SERVFAIL

    def test_rules(self):
        self.assertEqual(self.q("x.broken.example")["rcode"], 2)
        self.assertEqual(self.q("broken.example")["rcode"], 2)
        self.assertEqual(self.q("gone.shop.example")["rcode"], 3)
        self.assertEqual(self.q("blocked.example")["rcode"], 5)
        self.assertIsNone(self.q("dead.shop.example", timeout=1))
        self.assertIsNone(self.q("www.shop.example", "AAAA", timeout=1))
        t = time.time()
        self.assertIsNotNone(self.q("slow.shop.example", timeout=4))
        self.assertGreaterEqual(time.time() - t, 1.1)

    def test_truncation_forces_tcp(self):
        r = self.q("tc.shop.example")
        self.assertTrue(r["tc"])
        self.assertFalse(self.q("tc.shop.example", proto="tcp")["tc"])
        r = self.q("big.shop.example", "TXT", edns=False)  # > 512 bytes without EDNS
        self.assertTrue(r["tc"])
        self.assertEqual(r["an"], 0)
        r = self.q("big.shop.example", "TXT", proto="tcp")
        self.assertEqual((r["tc"], r["an"]), (False, 1))

    def test_query_log(self):
        self.q("www.shop.example")
        self.q("gone.shop.example", "MX")
        self.q("dead.shop.example", timeout=0.5)
        self.q("tc.shop.example")
        time.sleep(0.2)
        rows = [line.split() for line in self.log.read_text().splitlines()]
        self.assertEqual([(r[2], r[3], r[4], r[5]) for r in rows], [
            ("udp", "www.shop.example.", "A", "NOERROR"),
            ("udp", "gone.shop.example.", "MX", "NXDOMAIN"),
            ("udp", "dead.shop.example.", "A", "DROPPED"),
            ("udp", "tc.shop.example.", "A", "NXDOMAIN"),
        ])
        self.assertTrue(rows[0][1].startswith("127.0.0.1#"))
        self.assertEqual(rows[3][7], "tc")

    def test_reload_on_change(self):
        zone = self.tmp / "zone.db"
        zone.write_text(zone.read_text() + "new.shop.example. 30 A 10.1.1.1\n")
        self.assertEqual(self.q("new.shop.example")["answers"][0][3], "10.1.1.1")

    def test_auth_mode_and_outside_names(self):
        self.assertEqual(self.q("google.com")["rcode"], 3)  # resolver mode: NXDOMAIN
        port = int(self.start("dns_server.py", "--zone", self.tmp / "zone.db", "--mode", "auth",
                              port_file="auth.port"))
        r = dns_query(port, "www.shop.example")
        self.assertTrue(r["aa"])
        self.assertFalse(r["ra"])
        self.assertEqual(dns_query(port, "google.com")["rcode"], 5)

    def test_dig(self):
        dig = need("dig")
        base = [dig, "@127.0.0.1", "-p", str(self.port), "+time=2", "+tries=1"]
        self.assertEqual(run(base + ["shop.example", "MX", "+short"]).stdout.split("\n")[:2],
                         ["20 backup.shop.example.", "10 primary.shop.example."])
        self.assertEqual(run(base + ["primary.shop.example", "+short"]).stdout.split(),
                         ["relay.shop.example.", "mx-a.hosting.example.", "10.9.8.7"])
        self.assertEqual(run(base + ["-x", "10.0.0.5", "+short"]).stdout.strip(), "www.shop.example.")
        self.assertEqual(run(base + ["_sip._tcp.shop.example", "SRV", "+short"]).stdout.strip(),
                         "10 60 5060 sip.shop.example.")
        self.assertEqual(run(base + ["shop.example", "TXT", "+short"]).stdout.strip(), '"v=spf1 mx -all"')
        out = run(base + ["nope.shop.example"]).stdout
        self.assertIn("status: NXDOMAIN", out)
        self.assertRegex(out, r"shop\.example\.\s+120\s+IN\s+SOA\s+ns1\.shop\.example\. hostmaster")
        self.assertIn("status: SERVFAIL", run(base + ["a.broken.example"]).stdout)
        out = run(base + ["tc.shop.example"]).stdout
        self.assertIn("Truncated, retrying in TCP mode", out)
        self.assertIn("status: NXDOMAIN", out)
        self.assertIn("+tcp", run(base + ["+tcp", "www.shop.example"]).stdout)
        self.assertIn("10.0.0.5", run(base + ["+tcp", "www.shop.example", "+short"]).stdout)
        out = run(base + ["dead.shop.example"]).stdout
        self.assertRegex(out, r"timed out|no servers could be reached")
        self.assertIn("2026111001", run(base + ["shop.example", "SOA", "+short"]).stdout)

    def test_nslookup_and_host(self):
        nslookup = need("nslookup")
        out = run([nslookup, f"-port={self.port}", "-timeout=1", "-retry=1", "www.shop.example", "127.0.0.1"]).stdout
        self.assertIn("Address: 10.0.0.5", out)
        r = run([nslookup, f"-port={self.port}", "gone.shop.example", "127.0.0.1"])
        self.assertIn("NXDOMAIN", r.stdout)
        self.assertIn("SERVFAIL", run([nslookup, f"-port={self.port}", "x.broken.example", "127.0.0.1"]).stdout)
        out = run([nslookup, f"-port={self.port}", "10.0.0.5", "127.0.0.1"]).stdout
        self.assertIn("name = www.shop.example.", out)

    def test_host(self):
        host = need("host")
        r = run([host, "-p", str(self.port), "-W", "1", "10.0.0.5", "127.0.0.1"])
        if "illegal option" in r.stderr:
            self.skipTest("this host(1) has no -p option (old BIND on macOS); checked in the Docker image")
        out = r.stdout
        self.assertIn("domain name pointer www.shop.example.", out)
        out = run([host, "-p", str(self.port), "-t", "MX", "shop.example", "127.0.0.1"]).stdout
        self.assertIn("shop.example mail is handled by 10 primary.shop.example.", out)
        r = run([host, "-p", str(self.port), "nope.shop.example", "127.0.0.1"])
        self.assertIn("NXDOMAIN", r.stdout)
        self.assertNotEqual(r.returncode, 0)


class DNSCliTests(ServerCase):
    def test_check_and_errors(self):
        z = self.tmp / "z"
        z.write_text("$ORIGIN a.test.\nwww A 10.0.0.1\nwww CNAME x\n")
        r = run([PY, str(NET / "dns_server.py"), "--check", "--zone", str(z)])
        self.assertEqual(r.returncode, 2)
        self.assertIn("CNAME and other data", r.stderr)
        z.write_text("$ORIGIN a.test.\nwww A 300.0.0.1\n")
        self.assertIn(":2:", run([PY, str(NET / "dns_server.py"), "--check", "--zone", str(z)]).stderr)
        z.write_text("$ORIGIN a.test.\nwww 1h IN A 10.0.0.1\n     AAAA ::1\n")
        r = run([PY, str(NET / "dns_server.py"), "--check", "--zone", str(z)])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("2 records", r.stdout)

    def test_daemon_pid_and_idle_exit(self):
        z = self.tmp / "z"
        z.write_text("www.a.test. A 10.0.0.1\n")
        pf, pidf = self.tmp / "d.port", self.tmp / "d.pid"
        r = run([PY, str(NET / "dns_server.py"), "--zone", str(z), "--port-file", str(pf),
                 "--pid-file", str(pidf), "--daemon", "--idle-timeout", "2"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(pf.read_text().strip().isdigit())  # ready as soon as --daemon returns
        self.assertEqual(dns_query(int(pf.read_text()), "www.a.test")["answers"][0][3], "10.0.0.1")
        pid = int(pidf.read_text())
        deadline = time.time() + 8
        while time.time() < deadline:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            if Path(f"/proc/{pid}/stat").exists() and Path(f"/proc/{pid}/stat").read_text().split()[2] == "Z":
                break
            time.sleep(0.2)
        else:
            self.fail("daemon did not exit after its idle timeout")

    def test_wait_ready(self):
        pf = self.tmp / "later.port"
        p = subprocess.Popen([PY, str(NET / "dns_server.py"), "--wait-ready", str(pf), "--timeout", "5"],
                             stdout=subprocess.PIPE, text=True)
        time.sleep(0.3)
        pf.write_text("5353\n")
        self.assertEqual(p.communicate(timeout=5)[0].strip(), "5353")
        self.assertEqual(p.returncode, 0)
        r = run([PY, str(NET / "dns_server.py"), "--wait-ready", str(self.tmp / "never"), "--timeout", "0.3"])
        self.assertEqual(r.returncode, 1)


# --------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------
HTTP_CONFIG = """{
  "server": "nginx/1.24.0",
  "log_headers": ["Range"],
  "routes": [
    {"path": "/", "body": "home\\n", "headers": {"Cache-Control": "max-age=60", "Set-Cookie": ["a=1", "b=2"]}},
    {"path": "/old", "status": 301, "redirect": "/mid"},
    {"path": "/mid", "redirect": "/status", "headers": {"ETag": "\\"stale\\""}},
    {"path": "/status", "body": "v2\\n", "headers": {"ETag": "\\"v2\\""},
     "by_method": {"HEAD": {"headers": {"ETag": "\\"v1\\""}}}},
    {"path": "/loop-a", "redirect": "/loop-b"},
    {"path": "/loop-b", "redirect": "/loop-a"},
    {"path": "/slow", "delay": 1.0, "body": "late\\n"},
    {"path": "/hang", "hang": true},
    {"path": "/boom", "status": 503},
    {"path": "/flaky", "body": "ok\\n", "cycle": [{"status": 500}, {}, {}]},
    {"path": "/private", "auth": {"basic": ["ops:s3cret"], "realm": "ops"}, "body": "secret\\n"},
    {"path": "/api", "require_headers": {"X-API-Key": "k1"}, "json": {"ok": true}},
    {"path": "/members", "require_cookies": {"session": "abc"}, "body": "member\\n", "deny_status": 401},
    {"path": "/big.bin", "file": "big.bin", "abort_after": 40000},
    {"path": "/chunk", "body": "chunked body\\n", "chunked": true},
    {"path": "/gz", "body": "zip zip zip zip zip zip zip zip zip zip\\n", "gzip": true},
    {"path": "/reset", "action": "reset"},
    {"path": "/empty", "action": "close"},
    {"path": "/upload", "methods": ["POST"], "status": 201, "json": {"created": 1}},
    {"path": "/docs*", "dir": "site/docs"},
    {"path": "/*", "host": "updates.vendor.example", "body": "via proxy\\n"}
  ]
}"""


class HTTPServerTests(ServerCase):
    def setUp(self):
        super().setUp()
        (self.tmp / "http.json").write_text(HTTP_CONFIG)
        self.big = os.urandom(100000)
        (self.tmp / "big.bin").write_bytes(self.big)
        (self.tmp / "site/docs/img").mkdir(parents=True)
        (self.tmp / "site/docs/index.html").write_text('<a href="guide.html">g</a>')
        (self.tmp / "site/docs/guide.html").write_text("guide")
        self.log = self.tmp / "access.log"
        self.port = int(self.start("http_server.py", "--config", self.tmp / "http.json", "--log", self.log))
        self.base = f"http://127.0.0.1:{self.port}"

    def get(self, path, method="GET", headers=None, body=None):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        c.request(method, path, body=body, headers=headers or {})
        r = c.getresponse()
        data = r.read()
        c.close()
        return r, data

    def test_basic_headers_and_keepalive(self):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        for _ in range(2):  # same connection twice: HTTP/1.1 keep-alive works
            c.request("GET", "/")
            r = c.getresponse()
            self.assertEqual((r.status, r.read()), (200, b"home\n"))
        c.close()
        self.assertEqual(r.getheader("Server"), "nginx/1.24.0")
        self.assertEqual(r.getheader("Content-Length"), "5")
        self.assertEqual(r.msg.get_all("Set-Cookie"), ["a=1", "b=2"])
        r, data = self.get("/missing")
        self.assertEqual(r.status, 404)
        self.assertIn(b"404 Not Found", data)

    def test_redirects_head_override_and_conditional(self):
        r, _ = self.get("/old")
        self.assertEqual((r.status, r.getheader("Location")), (301, "/mid"))
        self.assertEqual(self.get("/mid")[0].status, 302)
        r, data = self.get("/status", "HEAD")
        self.assertEqual((r.getheader("ETag"), data), ('"v1"', b""))
        self.assertEqual(r.getheader("Content-Length"), "3")
        self.assertEqual(self.get("/status")[0].getheader("ETag"), '"v2"')
        self.assertEqual(self.get("/status", headers={"If-None-Match": '"v2"'})[0].status, 304)

    def test_auth_headers_cookies_methods(self):
        r, _ = self.get("/private")
        self.assertEqual(r.status, 401)
        self.assertEqual(r.getheader("WWW-Authenticate"), 'Basic realm="ops"')
        ok = base64.b64encode(b"ops:s3cret").decode()
        self.assertEqual(self.get("/private", headers={"Authorization": f"Basic {ok}"})[1], b"secret\n")
        self.assertEqual(self.get("/api")[0].status, 403)
        self.assertEqual(self.get("/api", headers={"X-API-Key": "k1"})[0].status, 200)
        self.assertEqual(self.get("/members")[0].status, 401)
        self.assertEqual(self.get("/members", headers={"Cookie": "x=1; session=abc"})[1], b"member\n")
        r, _ = self.get("/upload")
        self.assertEqual((r.status, r.getheader("Allow")), (405, "POST"))
        self.assertEqual(self.get("/upload", "POST", body=b"x=1")[0].status, 201)

    def test_cycle_status_and_ranges(self):
        self.assertEqual([self.get("/flaky")[0].status for _ in range(4)], [500, 200, 200, 500])
        self.assertEqual(self.get("/boom")[0].status, 503)
        r, data = self.get("/big.bin", headers={"Range": "bytes=10-19"})
        self.assertEqual((r.status, data), (206, self.big[10:20]))
        self.assertEqual(r.getheader("Content-Range"), "bytes 10-19/100000")
        r, data = self.get("/big.bin", headers={"Range": "bytes=40000-"})
        self.assertEqual(data, self.big[40000:])
        self.assertEqual(self.get("/big.bin", headers={"Range": "bytes=100000-"})[0].status, 416)

    def test_static_dir_chunked_gzip_proxy(self):
        r, data = self.get("/docs")
        self.assertEqual((r.status, r.getheader("Location")), (301, "/docs/"))
        r, data = self.get("/docs/")
        self.assertEqual(data, b'<a href="guide.html">g</a>')
        self.assertTrue(r.getheader("Content-Type").startswith("text/html"))
        self.assertEqual(self.get("/docs/../http.json")[0].status, 404)
        self.assertEqual(self.get("/docs/img/")[0].status, 403)
        r, data = self.get("/chunk")
        self.assertEqual((r.getheader("Transfer-Encoding"), data), ("chunked", b"chunked body\n"))
        import gzip
        r, data = self.get("/gz", headers={"Accept-Encoding": "gzip"})
        self.assertEqual(r.getheader("Content-Encoding"), "gzip")
        self.assertEqual(gzip.decompress(data), b"zip zip zip zip zip zip zip zip zip zip\n")
        self.assertIsNone(self.get("/gz")[0].getheader("Content-Encoding"))
        r, data = self.get("http://updates.vendor.example/pkgs")
        self.assertEqual(data, b"via proxy\n")

    def test_access_log(self):
        self.get("/")
        self.get("/big.bin", headers={"Range": "bytes=0-9", "User-Agent": "tester/1"})
        self.get("http://updates.vendor.example/x")
        lines = self.log.read_text().splitlines()
        self.assertRegex(lines[0], r'^127\.0\.0\.1 - - \[[^]]+\] "GET / HTTP/1\.1" 200 5 "-" "[^"]*" host="127\.0\.0\.1:\d+" rt=')
        self.assertIn('"GET /big.bin HTTP/1.1" 206 10 "-" "tester/1"', lines[1])
        self.assertTrue(lines[1].endswith('range="bytes=0-9"'))
        self.assertIn('"GET http://updates.vendor.example/x HTTP/1.1" 200', lines[2])

    def test_reset_close_and_abort(self):
        with self.assertRaises((ConnectionError, http.client.RemoteDisconnected)):
            self.get("/reset")
        with self.assertRaises(http.client.RemoteDisconnected):
            self.get("/empty")
        with self.assertRaises(http.client.IncompleteRead):
            self.get("/big.bin")

    def test_reload_and_bad_config(self):
        cfg = self.tmp / "http.json"
        cfg.write_text(cfg.read_text().replace('"home\\n"', '"changed\\n"'))
        self.assertEqual(self.get("/")[1], b"changed\n")
        (self.tmp / "bad.json").write_text('{"routes": [{"path": "/", "bogus": 1}]}')
        r = run([PY, str(NET / "http_server.py"), "--check", "--config", str(self.tmp / "bad.json")])
        self.assertEqual(r.returncode, 2)
        self.assertIn("bogus", r.stderr)

    def test_curl(self):
        curl = need("curl")
        out = run([curl, "-sL", "-o", "/dev/null", "-w", "%{url_effective} %{http_code} %{num_redirects}",
                   self.base + "/old"]).stdout
        self.assertEqual(out, f"{self.base}/status 200 2")
        self.assertEqual(run([curl, "-sL", "--max-redirs", "5", self.base + "/loop-a"]).returncode, 47)
        r = run([curl, "-s", "-o", "/dev/null", "--max-time", "1", "-w", "%{http_code}", self.base + "/hang"])
        self.assertEqual((r.returncode, r.stdout), (28, "000"))
        out = run([curl, "-s", "-o", "/dev/null", "-w", "%{http_code} %{time_total}", self.base + "/slow"]).stdout
        self.assertEqual(out.split()[0], "200")
        self.assertGreaterEqual(float(out.split()[1]), 0.9)
        self.assertEqual(run([curl, "-s", self.base + "/reset"]).returncode, 56)
        self.assertEqual(run([curl, "-s", self.base + "/empty"]).returncode, 52)
        self.assertEqual(run([curl, "-s", "--compressed", self.base + "/gz"]).stdout,
                         "zip zip zip zip zip zip zip zip zip zip\n")
        self.assertEqual(run([curl, "-s", "-x", self.base, "http://updates.vendor.example/a"]).stdout, "via proxy\n")
        part = self.tmp / "part.bin"
        r = run([curl, "-s", "-o", str(part), self.base + "/big.bin"])
        self.assertEqual((r.returncode, part.stat().st_size), (18, 40000))
        r = run([curl, "-s", "-C", "-", "-o", str(part), self.base + "/big.bin"])
        self.assertEqual(r.returncode, 0)
        self.assertEqual(part.read_bytes(), self.big)

    def test_wget(self):
        wget = need("wget")
        out = self.tmp / "w.bin"
        out.write_bytes(self.big[:30000])
        r = run([wget, "-q", "-c", "-O", str(out), self.base + "/big.bin"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(out.read_bytes(), self.big)
        self.assertIn('range="bytes=30000-"', self.log.read_text())
        mirror = self.tmp / "mirror"
        mirror.mkdir()
        r = run([wget, "-q", "-r", "-np", "-nH", self.base + "/docs/"], cwd=mirror)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((mirror / "docs/guide.html").exists())

    def test_tls(self):
        openssl, curl = need("openssl"), need("curl")
        cert, key = self.tmp / "cert.pem", self.tmp / "key.pem"
        r = run([openssl, "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "2", "-subj", "/CN=localhost",
                 "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1", "-keyout", str(key), "-out", str(cert)])
        if r.returncode:
            self.skipTest(f"openssl could not make a test certificate: {r.stderr.strip()}")
        port = self.start("http_server.py", "--config", self.tmp / "http.json", "--tls-cert", cert,
                          "--tls-key", key, port_file="tls.port")
        r = run([curl, "-s", "--cacert", str(cert), f"https://127.0.0.1:{port}/"])
        self.assertEqual((r.returncode, r.stdout), (0, "home\n"))
        # untrusted self-signed cert: 60 (bad cert), or 77 where no CA bundle is installed
        self.assertIn(run([curl, "-s", f"https://127.0.0.1:{port}/"]).returncode, (60, 77))
        self.assertEqual(run([curl, "-sk", f"https://127.0.0.1:{port}/"]).stdout, "home\n")
        ctx = ssl.create_default_context(cafile=str(cert))
        c = http.client.HTTPSConnection("127.0.0.1", int(port), context=ctx, timeout=5)
        c.request("GET", "/status")
        self.assertEqual(c.getresponse().read(), b"v2\n")
        c.close()


# --------------------------------------------------------------------------
# SMTP
# --------------------------------------------------------------------------
class SMTPClient:
    def __init__(self, test, port):
        self.s = socket.create_connection(("127.0.0.1", port), timeout=5)
        self.f = self.s.makefile("rb")
        test.addCleanup(self.s.close)
        test.addCleanup(self.f.close)

    def reply(self):
        lines = []
        while True:
            line = self.f.readline().decode().rstrip("\r\n")
            lines.append(line)
            if len(line) < 4 or line[3] != "-":
                return "\n".join(lines)

    def cmd(self, text, raw=False):
        self.s.sendall(text.encode() if raw else text.encode() + b"\r\n")
        return self.reply()


class SMTPServerTests(ServerCase):
    def setUp(self):
        super().setUp()
        self.log, self.spool = self.tmp / "smtp.log", self.tmp / "spool"
        self.port = int(self.start("smtp_server.py", "--hostname", "mail.corp.example", "--domain", "corp.example",
                                   "--mailbox", "ops@corp.example", "--log", self.log, "--spool", self.spool,
                                   "--strict", "--sync-window", "0.15"))

    def test_dialogue_log_and_spool(self):
        c = SMTPClient(self, self.port)
        self.assertEqual(c.reply(), "220 mail.corp.example ESMTP Postfix (Ubuntu)")
        self.assertEqual(c.cmd("MAIL FROM:<a@b.example>")[:3], "503")
        ehlo = c.cmd("EHLO client.test")
        self.assertTrue(ehlo.startswith("250-mail.corp.example"))
        self.assertNotIn("PIPELINING", ehlo)  # strict mode does not offer it
        self.assertEqual(c.cmd("MAIL FROM:<me@x.example>"), "250 2.1.0 Ok")
        self.assertTrue(c.cmd("RCPT TO:<x@elsewhere.example>").startswith("454 4.7.1"))
        self.assertTrue(c.cmd("RCPT TO:<nobody@corp.example>").startswith("550 5.1.1"))
        self.assertEqual(c.cmd("RCPT TO:<ops@corp.example>"), "250 2.1.5 Ok")
        self.assertEqual(c.cmd("DATA")[:3], "354")
        r = c.cmd("Subject: Disk alert 7\r\nFrom: me\r\n\r\nbody\r\n..starts with dot\r\n.\r\n", raw=True)
        self.assertRegex(r, r"^250 2\.0\.0 Ok: queued as [0-9A-F]{10}$")
        qid = r.split()[-1]
        self.assertEqual(c.cmd("QUIT"), "221 2.0.0 Bye")
        time.sleep(0.2)
        log = self.log.read_text()
        self.assertIn(f"queued {qid} from=<me@x.example> to=<ops@corp.example>", log)
        self.assertIn('subject="Disk alert 7"', log)
        self.assertIn("C: RCPT TO:<ops@corp.example>", log)
        msg = (self.spool / f"{qid}.eml").read_text()
        self.assertIn("X-Original-To: ops@corp.example", msg)
        self.assertIn("\n.starts with dot", msg)

    def test_strict_sync_and_bare_lf(self):
        c = SMTPClient(self, self.port)
        c.reply()
        r = c.cmd("HELO a\r\nMAIL FROM:<x@y.example>\r\n", raw=True)
        self.assertTrue(r.startswith("554 5.5.0"), r)
        c = SMTPClient(self, self.port)  # talks before the greeting
        c.s.sendall(b"HELO a\r\n")
        self.assertTrue(c.reply().startswith("554"))
        c = SMTPClient(self, self.port)
        c.reply()
        self.assertTrue(c.cmd("HELO a\n", raw=True).startswith("521 5.5.2"))
        c = SMTPClient(self, self.port)  # message ended with LF.LF instead of CRLF.CRLF
        c.reply()
        c.cmd("HELO a")
        c.cmd("MAIL FROM:<x@y.example>")
        c.cmd("RCPT TO:<ops@corp.example>")
        c.cmd("DATA")
        self.assertTrue(c.cmd("Subject: x\r\n\r\nhi\n.\n", raw=True).startswith("521"))
        time.sleep(0.2)
        self.assertNotIn("queued", self.log.read_text())

    def test_bash_dev_tcp(self):
        bash = need("bash")
        script = f"""
exec 3<>/dev/tcp/127.0.0.1/{self.port}
read -r banner <&3
say() {{ printf '%s\\r\\n' "$1" >&3; read -r reply <&3; echo "${{reply%$'\\r'}}"; }}
say 'HELO box'
say 'MAIL FROM:<root@box>'
say 'RCPT TO:<ops@corp.example>'
say 'DATA'
printf 'Subject: via dev tcp\\r\\n\\r\\nhello\\r\\n.\\r\\n' >&3; read -r reply <&3; echo "$reply"
say 'QUIT'
"""
        r = run([bash, "-c", script])
        self.assertIn("250 2.0.0 Ok: queued as", r.stdout, r.stdout + r.stderr)
        self.assertIn('subject="via dev tcp"', self.log.read_text())

    def test_non_strict_allows_pipelining(self):
        port = int(self.start("smtp_server.py", port_file="loose.port"))
        c = SMTPClient(self, port)
        c.reply()
        self.assertIn("PIPELINING", c.cmd("EHLO a"))
        c.s.sendall(b"MAIL FROM:<a@b.example>\r\nRCPT TO:<c@d.example>\r\n")
        self.assertEqual((c.reply(), c.reply()), ("250 2.1.0 Ok", "250 2.1.5 Ok"))


# --------------------------------------------------------------------------
# Generic TCP services
# --------------------------------------------------------------------------
TCP_CONFIG = """{"listeners": [
  {"name": "status", "mode": "line", "replies": {"STATUS": "OK token=t0k3n"}},
  {"name": "ssh", "mode": "banner", "banner": "SSH-2.0-OpenSSH_9.6p1"},
  {"name": "echo", "mode": "echo"},
  {"name": "rst", "mode": "reset"},
  {"name": "eof", "mode": "close"},
  {"name": "quiet", "mode": "silent"},
  {"name": "hole", "mode": "blackhole"}
]}"""


class TCPServerTests(ServerCase):
    def setUp(self):
        super().setUp()
        (self.tmp / "tcp.json").write_text(TCP_CONFIG)
        self.log = self.tmp / "tcp.log"
        text = self.start("tcp_server.py", "--config", self.tmp / "tcp.json", "--log", self.log)
        self.ports = {n: int(p) for n, p in (line.split() for line in text.splitlines())}

    def conn(self, name, timeout=3):
        s = socket.create_connection(("127.0.0.1", self.ports[name]), timeout=timeout)
        self.addCleanup(s.close)
        return s

    def test_port_file_lists_every_listener(self):
        self.assertEqual(sorted(self.ports), sorted(["status", "ssh", "echo", "rst", "eof", "quiet", "hole"]))

    def test_line_banner_echo(self):
        s = self.conn("status", timeout=0.5)
        with self.assertRaises(socket.timeout):
            s.recv(100)  # silent until the client speaks
        s.settimeout(3)
        s.sendall(b"status\n")
        self.assertEqual(s.recv(100), b"OK token=t0k3n\n")
        s.sendall(b"what\n")
        self.assertEqual(s.recv(100), b"ERR unknown command\n")
        s.sendall(b"QUIT\n")
        self.assertEqual(s.recv(100), b"BYE\n")
        s = self.conn("ssh")
        self.assertEqual(s.recv(100), b"SSH-2.0-OpenSSH_9.6p1\n")
        self.assertEqual(s.recv(100), b"")
        s = self.conn("echo")
        s.sendall(b"ping\r\n")
        self.assertEqual(s.recv(100), b"ping\n")
        time.sleep(0.1)
        self.assertIn("status 127.0.0.1:", self.log.read_text())
        self.assertIn("C: status", self.log.read_text())

    def test_reset_close_silent(self):
        s = self.conn("rst")
        time.sleep(0.2)
        with self.assertRaises(ConnectionError):  # reset (Linux) or broken pipe (macOS)
            s.sendall(b"x\n")
            time.sleep(0.1)
            s.recv(100)
        s = self.conn("eof")
        self.assertEqual(s.recv(100), b"")
        s = self.conn("quiet", timeout=0.5)
        s.sendall(b"hello\n")
        with self.assertRaises(socket.timeout):
            s.recv(100)

    def test_blackhole_times_out(self):
        if not sys.platform.startswith("linux"):
            self.skipTest("blackhole relies on Linux dropping SYNs when the accept queue is full")
        t = time.time()
        with self.assertRaises((socket.timeout, TimeoutError)):
            self.conn("hole", timeout=1)
        self.assertGreaterEqual(time.time() - t, 0.9)

    def test_nc(self):
        nc = need("nc")
        if not sys.platform.startswith("linux"):
            self.skipTest("nc flags differ outside the Linux reference image")
        r = run([nc, "-zv", "-w2", "127.0.0.1", str(self.ports["status"])])
        self.assertEqual(r.returncode, 0)
        r = run([nc, "-q1", "-w2", "127.0.0.1", str(self.ports["status"])], input="STATUS\n")
        self.assertEqual(r.stdout, "OK token=t0k3n\n")
        r = run([nc, "-zv", "-w1", "127.0.0.1", str(self.ports["hole"])])
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("timed out", r.stderr)

    def test_single_listener_cli(self):
        port = int(self.start("tcp_server.py", "--mode", "line", "--reply", "PING=PONG", "--crlf",
                              "--host", "127.0.0.1", port_file="one.port"))
        s = socket.create_connection(("127.0.0.1", port), timeout=3)
        self.addCleanup(s.close)
        s.sendall(b"ping\n")
        self.assertEqual(s.recv(100), b"PONG\r\n")


if __name__ == "__main__":
    unittest.main()
