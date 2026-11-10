# Shared mocks

Stand-ins for tools that need root, a daemon or the network (see rule 7 in
`docs/LEVEL_AUTHORING.md`). A level's setup.sh copies what it needs into `$SANDBOX`;
everything level-specific (data, scenario, checks) stays in the level folder.
From a level's setup.sh the mocks are at `"$(dirname "$0")/../../../mocks"`.
Each section below documents one group of mocks.

## net/ — loopback network services (DNS, HTTP, SMTP, TCP)

Real servers on 127.0.0.1 that the real client tools talk to: `dig`, `nslookup`,
`host`, `curl`, `wget`, `nc`, `openssl s_client`, bash `/dev/tcp`. Python 3
stdlib only, one self-contained file per server, no root, nothing outside
loopback. Tests: `tests/test_mocks_net.py`.

| file | serves | used by (module 19 unless noted) |
|------|--------|---------|
| `net/dns_server.py` | DNS over UDP+TCP from BIND-style zone files, with failure knobs | 5 dig, 6 nslookup, 7 host, 14 resolv.conf, 23 dns triage |
| `net/http_server.py` | HTTP/1.1 (optional TLS) from a JSON route table; also a forward proxy | 8 headers, 9 wget mirror, 16 proxy, 17 status, 24 outage; curl/wget levels elsewhere |
| `net/smtp_server.py` | Postfix-like SMTP, optional strict synchronisation / CRLF checks | 12 bash /dev/tcp |
| `net/tcp_server.py` | line-protocol, banner, echo, silent, close, reset, blackhole ports | 10 ss ports, 11 nc, 24 outage |

### Starting one from setup.sh

Every server takes the same lifecycle options:

| option | meaning |
|--------|---------|
| `--port N` | port to bind; `0` (default) picks a free one |
| `--host ADDR` | bind address (default `127.0.0.1`; `::1` works) |
| `--port-file F` | written atomically once the socket is listening. It is the ready file. |
| `--daemon` | fork into the background and return **after** the socket is bound and the port file is written; stdin/stdout/stderr of the daemon go to `/dev/null`; exit status is non-zero (with a message on stderr) if the config is bad or the port is taken |
| `--pid-file F` | PID of the serving process (for levels that make the player kill / signal it) |
| `--idle-timeout S` | exit after S seconds without a request (default 7200; `0` = never) |
| `--max-lifetime S` | exit after S seconds in total (default 21600 = 6 h; `0` = never) |
| `--wait-ready F [--timeout S]` | helper mode: wait until port file F is non-empty, print it, exit 0 (1 on timeout) |

Copy the server into the sandbox so the sandbox path is in its command line (rule 5:
the engine stops it with `pkill -f $SANDBOX` on reset), and use `--daemon` so setup.sh
continues only once the server is ready:

```bash
SANDBOX="$1"
NET="$SANDBOX/.net"; mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/dns_server.py" "$NET/"
# ... write "$NET/zone.db" (and "$NET/rules") for this level ...
python3 "$NET/dns_server.py" --zone "$NET/zone.db" --rules "$NET/rules" \
    --log "$NET/query.log" --port-file "$NET/dns.port" --daemon \
  || { echo "could not start the DNS server" >&2; exit 1; }
PORT=$(cat "$NET/dns.port")
```

The `&` style works too and is equally race-free:

```bash
python3 "$NET/http_server.py" --config "$NET/http.json" --port-file "$NET/http.port" >/dev/null 2>&1 &
PORT=$(python3 "$NET/http_server.py" --wait-ready "$NET/http.port") || exit 1
```

A fixed port (`--port 5353`) is fine when the ticket names it; with `--port 0` write the
port somewhere the player can read it (e.g. `server.txt`) or put it in the mission text.
Servers re-read their zone / rules / config file when it changes, so a level can
change data mid-scenario (or let the player fix it) without a restart. Each server
has `--help`.

### dns_server.py

```
dns_server.py --zone FILE [--zone FILE ...] [--rules FILE] [--log FILE]
              [--mode resolver|auth] [--check]  + lifecycle options
```

Query it with `dig @127.0.0.1 -p PORT name [type] [+short] [+tcp]`, `dig -x IP`,
`nslookup -port=PORT name 127.0.0.1`, `host -p PORT name 127.0.0.1` (Ubuntu's host;
macOS's old `host` has no `-p`).

**Zone file**: the usual BIND master-file syntax: `$ORIGIN`, `$TTL`, `@`, relative and
absolute names, optional per-record TTL (`300`, `1h`, `2d`) and class `IN` in either
order, a blank owner repeats the previous one, `;` comments, `( ... )` across lines,
quoted strings for TXT. Types: A, AAAA, CNAME, MX, TXT, NS, SOA, PTR, SRV. Wildcards
(`*.dyn A 10.0.0.9`) and empty non-terminals behave as in BIND. Several `$ORIGIN`
blocks and several `--zone` files may be combined. `--check` parses and reports
(exit 2 with `file:line: problem` on errors like "CNAME and other data").

```
$ORIGIN shop.example.
$TTL 300
@       IN SOA ns1 hostmaster ( 2026111001 3600 600 86400 300 )
@          NS    ns1
ns1        A     127.0.0.1
@          MX    10 mail
mail   60  CNAME relay.hosting.example.
www        A     10.0.0.5
www        AAAA  2001:db8::5
@          TXT   "v=spf1 mx -all"
_sip._tcp  SRV   10 60 5060 sip
5.0.0.10.in-addr.arpa. PTR www.shop.example.
```

An SOA marks a zone apex. It is needed for SOA/NS queries, serials, and the SOA in
the authority section of NXDOMAIN / no-data answers. Records outside any SOA'd zone
(e.g. a few PTRs) are still served.

**Answers**: CNAME chains are followed (across zones too) and all hops are returned;
MX/NS/SRV targets get their A/AAAA in the additional section; records come back in
zone-file order (deterministic); NXDOMAIN vs NOERROR/no-data is exact; a CNAME loop
gives SERVFAIL. EDNS is answered (udp 1232, DNS cookie echoed, so dig shows
`COOKIE: ... (good)`); answers larger than the client's UDP size come back with TC set
and dig/nslookup retry over TCP by themselves.

- `--mode resolver` (default) looks like a caching resolver (127.0.0.53-style): `ra`
  set, no `aa` (nslookup prints "Non-authoritative answer"); names outside the data get
  NXDOMAIN with the root SOA.
- `--mode auth` looks like an authoritative-only server: `aa` set, no `ra` (dig prints
  "recursion requested but not available"), REFUSED for names outside its zones.
  Run two instances (primary/secondary) with different zone files for serial-mismatch levels.

**Rules** (`--rules FILE`): first matching line wins; `#` comments.

```
# pattern             actions
.broken.example.      servfail          # the name and everything below it
gone.shop.example     nxdomain          # exact name (trailing dot optional)
*.blocked.example.    refused           # only names below it
dead.shop.example     drop              # never answer: client times out
www.shop.example      drop type=AAAA    # only AAAA queries for it
ghost.shop.example    nodata            # NOERROR, empty answer, SOA in authority
big.shop.example      truncate          # UDP answer has TC set, so client retries over TCP
slow.shop.example     delay=2.5         # answer normally after 2.5 s
flaky.shop.example    delay=1 servfail  # actions combine
*                     drop              # a dead nameserver (whole server)
```

Actions: `nxdomain`, `servfail`, `refused`, `formerr`, `notimp`, `nodata`, `drop`,
`truncate` (alias `tc`), `delay=SECONDS`, `type=QTYPE` (restricts the rule).
Rules apply to the queried name. Over TCP, `drop` keeps the connection open silently.

**Query log** (`--log`): one line per query, space-separated, easy to `awk`:

```
2026-11-10T11:54:58.899 127.0.0.1#59623 udp shop.example. MX NOERROR 2 -
2026-11-10T11:55:00.093 127.0.0.1#53032 udp big.shop.example. TXT NOERROR 1 tc
2026-11-10T11:55:00.094 127.0.0.1#36595 tcp big.shop.example. TXT NOERROR 1 -
2026-11-10T11:54:59.069 127.0.0.1#41643 udp dead.shop.example. A DROPPED 0 -
```

Fields: local time, client `ip#port`, `udp|tcp`, qname (lower case, trailing dot), qtype,
result (`NOERROR NXDOMAIN SERVFAIL REFUSED FORMERR NOTIMP` or `DROPPED`), number of
answer records, notes (`tc`, `delay=S`, or `-`).

### http_server.py

```
http_server.py --config FILE.json [--log FILE] [--tls-cert PEM [--tls-key PEM]] [--check]
               + lifecycle options
```

**Config** (JSON). Paths are relative to the config file's directory:

```json
{
  "server": "nginx/1.24.0",
  "log_headers": ["Range", "X-API-Key"],
  "tls": {"cert": "tls/cert.pem", "key": "tls/key.pem"},
  "routes": [
    {"path": "/", "body": "hello\n", "headers": {"Cache-Control": "max-age=60"}},
    {"path": "/old", "status": 301, "redirect": "/new"},
    {"path": "/new", "redirect": "/status"},
    {"path": "/status", "json": {"ok": true}, "headers": {"ETag": "\"v2\""},
     "by_method": {"HEAD": {"headers": {"ETag": "\"v1\""}}}},
    {"path": "/loop", "redirect": "/loop"},
    {"path": "/slow", "delay": 3, "body": "late\n"},
    {"path": "/hang", "hang": true},
    {"path": "/flaky", "body": "ok\n", "cycle": [{"status": 503}, {}, {}]},
    {"path": "/admin", "auth": {"basic": ["ops:s3cret"], "realm": "ops"}, "body": "hi\n"},
    {"path": "/api/*", "require_headers": {"X-API-Key": "k-123"}, "deny_status": 401, "json": {}},
    {"path": "/members", "require_cookies": {"session": "abc"}, "body": "welcome\n"},
    {"path": "/iso/big.iso", "file": "files/big.iso", "rate": 200000, "abort_after": 1000000},
    {"path": "/stream", "body": "...", "chunked": true},
    {"path": "/page", "file": "files/page.html", "gzip": true},
    {"path": "/drop", "action": "reset"},
    {"path": "/docs*", "dir": "site/docs", "autoindex": false},
    {"path": "/robots.txt", "body": "User-agent: *\nDisallow: /docs/old/\n"},
    {"path": "/*", "host": "updates.vendor.example", "body": "vendor index\n"}
  ]
}
```

Routes are matched in order on the path without the query string. `"path"` is exact, or
a prefix when it ends in `*`. `"host"` (optional) must equal the Host header, or the
host of an absolute-form request URL. No match gives an nginx-style 404.

| key | effect |
|-----|--------|
| `status`, `reason` | status code (default 200, or 302 with `redirect`) and optional custom reason phrase |
| `headers` | extra headers; a list value sends the header several times (`"Set-Cookie": ["a=1", "b=2"]`) |
| `body` / `json` / `file` / `dir` | text body (text/plain), JSON body, a file (type from extension), or a static tree under a `*` prefix route: index.html, `/dir` → 301 `/dir/`, 403 for a directory without index unless `"autoindex": true`, `Last-Modified` from mtime, no escaping the tree |
| `content_type` | override Content-Type |
| `methods` | allowed methods (default `["GET", "HEAD"]`); others get 405 with `Allow` |
| `redirect` | `Location` value (relative or absolute); chains and loops are just routes pointing at each other |
| `auth` | `{"basic": ["user:pass", ...]}` or `{"bearer": ["token", ...]}`, optional `realm`: 401 + `WWW-Authenticate` when missing/wrong; the user name is logged |
| `require_headers` / `require_cookies` | `{"Name": "value"}` (`null` = just present); otherwise `deny_status` (default 403) with `deny_body` |
| `by_method` | `{"HEAD": {...}}`: keys merged over the route for that method (HEAD answering differently from GET) |
| `cycle` | list of override objects applied in turn per request (`[{"status": 500}, {}, {}]` = every 3rd request fails) |
| `delay` / `hang` | wait N seconds before answering / never answer (curl `--max-time` → `000`, exit 28) |
| `rate` | throttle the body to N bytes/s |
| `abort_after` | on a request without `Range`, send only N body bytes and close (curl exit 18) so `curl -C -` / `wget -c` can resume |
| `ranges` | Range support (default on): 206 + `Content-Range`, 416 when unsatisfiable, `Accept-Ranges: bytes` |
| `chunked` | `Transfer-Encoding: chunked` |
| `gzip` | gzip the body when the request has `Accept-Encoding: gzip` (`curl --compressed`); adds `Vary` |
| `action` | `"reset"`: RST without a response (curl 56); `"close"`: close without a response (curl 52, "Empty reply from server") |

Also: HTTP/1.1 keep-alive; HEAD sends GET's headers and Content-Length without a body;
`If-None-Match` matching an `ETag` header, or `If-Modified-Since` not older than
`Last-Modified`, gives 304; request bodies (Content-Length or chunked) are read and
discarded. **Proxy**: a request in absolute form (`GET http://host/path`, which clients
send to an HTTP proxy) is matched on that URL's host and path and logged with the full
URL, so one instance can act as the forward proxy for `http_proxy=http://127.0.0.1:PORT`
(e.g. with `"host": "updates.vendor.example"` routes). CONNECT isn't supported, so
there's no HTTPS through the proxy. **TLS**: `--tls-cert/--tls-key`, or `"tls"` in the
config, serves HTTPS on the same port. The level makes the certificate, e.g.
`openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj /CN=localhost -addext subjectAltName=DNS:localhost,IP:127.0.0.1 -keyout key.pem -out cert.pem`.
The reference image has no CA bundle, so curl without `--cacert`/`-k` fails with exit 77.

**Access log** (`--log`): nginx "combined" plus extras:

```
127.0.0.1 - ops [10/Nov/2026:11:58:18 +0000] "GET /private HTTP/1.1" 200 7 "-" "curl/8.5.0" host="127.0.0.1:39831" rt=0.000 range="-" x-api-key="-"
127.0.0.1 - - [10/Nov/2026:11:58:20 +0000] "GET http://updates.vendor.example/vendor/list HTTP/1.1" 200 9 "-" "curl/8.5.0" host="updates.vendor.example" rt=0.000 range="-" x-api-key="-"
```

Status is what was sent; the byte count is body bytes actually written. `444` = `action`
closed/reset without a response, `499` = the client went away mid-response (e.g. curl
`--max-time`). One `name="value"` per `log_headers` entry (`"-"` when absent).

### smtp_server.py

```
smtp_server.py [--hostname mail.corp.example] [--domain corp.example ...] [--mailbox ops@corp.example ...]
               [--log FILE] [--spool DIR] [--strict [--sync-window 0.3]] + lifecycle options
```

Greeting `220 <hostname> ESMTP Postfix (Ubuntu)`; HELO, EHLO (multi-line `250-`), MAIL
FROM, RCPT TO, DATA (`354 End data with <CR><LF>.<CR><LF>`, dot-unstuffing), RSET, NOOP,
VRFY, QUIT, with Postfix's reply codes and texts for out-of-order commands (503),
syntax errors (501), relay denied for other domains (454, with `--domain`) and unknown
users (550, with `--mailbox`). Each accepted message gets `250 2.0.0 Ok: queued as <ID>`.

`--strict` adds the checks a hand-written client must pass. It doesn't offer PIPELINING.
A client that sends before the greeting, or sends the next command before the previous
reply (the server waits `--sync-window` seconds before each reply to catch it), gets
`554 5.5.0 SMTP synchronization error` and is disconnected. A command or message line
that ends in a bare LF (including a final `.` that isn't `\r\n.\r\n`) gets `521 5.5.2 Error:
bare <LF> received` and is disconnected. Without `--strict`, pipelining is offered and allowed.

**Log** (`--log`): the conversation, plus one `queued` line per accepted message:

```
2026-11-10T12:00:53.606 #1 C: EHLO me
2026-11-10T12:00:53.907 #1 S: 250-mail.corp.example
2026-11-10T12:00:55.416 #1 C: <5 lines of message data>
2026-11-10T12:00:55.718 #1 queued 217FAA7969 from=<me@x.example> to=<ops@corp.example> size=43 subject="Test 42"
```

`#N` numbers the connections; other lines are `connect from IP:PORT`, `disconnect`,
`sync error: ...`, `bare LF: ...`. `--spool DIR` saves each message as `DIR/<ID>.eml`
(`Return-Path`, `X-Original-To`, `Received` + the message as sent, dot-unstuffed).

### tcp_server.py

One listener from the command line, or several from a JSON config:

```
tcp_server.py [--mode MODE] [--banner TEXT] [--reply CMD=TEXT ...] [--default-reply TEXT]
              [--crlf] [--delay S] [--name LABEL] [--log FILE] + lifecycle options
tcp_server.py --config FILE.json [--log FILE] + lifecycle options
```

```json
{"listeners": [
  {"name": "status", "mode": "line", "replies": {"STATUS": "OK token=4f2a"}},
  {"name": "legacy", "host": "::1", "port": 0, "mode": "banner", "banner": "SSH-2.0-OpenSSH_9.6p1"},
  {"name": "flappy", "mode": "reset"},
  {"name": "filtered", "mode": "blackhole"}
]}
```

| mode | behaviour |
|------|-----------|
| `line` (default) | sends `banner` if set, else nothing until the client speaks; each line is answered from `replies` (whole line or first word, case-insensitive), else `default_reply` (`ERR unknown command`); `QUIT` → `quit_reply` (`BYE`) and close |
| `echo` | every line sent back |
| `banner` | sends the banner and closes |
| `silent` | accepts, reads, never answers (`nc` without `-w` hangs) |
| `close` | accepts and closes at once |
| `reset` | accepts and sends a TCP RST (`Connection reset by peer`) |
| `blackhole` | listens, but its accept queue is kept full so connects time out like a firewalled port (`nc -zv -w2` → "timed out"; curl exit 28). Linux behaviour; `ss -ltn` shows it LISTEN with Recv-Q 1. It gets no traffic, so give such servers `--idle-timeout 0` |

Other listener keys: `host`, `port` (0 = free), `crlf` (end replies with CRLF), `delay`
(seconds before each reply), `quit_reply`. Port file: with `--config`, one `name port`
line per listener (`awk '$1=="status"{print $2}'`); single listener: just the port.
Run separate processes when the level makes the player kill one service (`ss -ltnp`
shows one PID per process). **Log**: `TIME LABEL IP:PORT connect|C: line|S: line|reset|disconnect`.
