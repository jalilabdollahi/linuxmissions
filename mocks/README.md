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

## systemd/ — systemctl, journalctl, systemd-analyze, timedatectl

One Python 3 stdlib program, `systemd/systemd-mock`, run under four names
(`systemctl`, `journalctl`, `systemd-analyze` and `timedatectl` are symlinks to it).
Output formats and exit codes follow systemd 255 on Ubuntu 24.04. It runs on
macOS too (Python 3.9+). Tests: `tests/test_mocks_systemd.py`.
Used by module 13 (services and logs), 23 (boot), 24, 26 (wargames 10/23/30), 16 (21).

### Shipping it

```bash
M="$(dirname "$0")/../../../mocks"
cp "$M/systemd/systemctl" "$M/systemd/journalctl" "$SANDBOX/"     # plain cp follows the symlink
```

Use plain `cp` for single tools. `cp -P`/`cp -a` would copy a dangling symlink,
unless you copy the whole `systemd/` folder. The player then runs `./systemctl …`.

**Fake root.** `/` for the mock is `$LM_ROOT` if set, otherwise the directory
that holds the tool. A trailing `bin/`, `sbin/`, `usr/` or `local/` without an
`etc/` is skipped, so `$SANDBOX/systemctl` and `$SANDBOX/bin/systemctl` both use
`$SANDBOX`. For a captured `sysroot/`, put the tool inside it, or ship a two-line
wrapper that sets `LM_ROOT`.

### Fixture files a level writes (all optional)

| path in the fake root | what |
|---|---|
| `etc/systemd/system/`, `run/systemd/system/`, `usr/local/lib/systemd/system/`, `usr/lib/systemd/system/`, `lib/systemd/system/` (+ `*.control`, `run/systemd/transient`) | unit files, in systemd's priority order. Drop-ins: `<unit>.d/*.conf`, `<template@>.d/`, `service.d/` |
| `.lm/now` | frozen clock: `2026-11-10 03:10:00` (local time), `2026-11-10T03:10:00+03:30`, `@1794283800`. Without it the real clock is used. |
| `etc/timezone` (or `etc/localtime` → `…/zoneinfo/Zone`) | local time zone (default UTC). `timedatectl set-timezone` writes both. |
| `etc/hostname` | hostname in journal lines (default `localhost`) |
| `etc/passwd` | only to check `User=`: a missing user gives `217/USER` (skipped when there is no passwd) |
| `var/log/journal/*.json` (and one subdirectory level) | the journal: JSON lines as written by `journalctl -o json` |
| `.lm/boot_id` | which `_BOOT_ID` is the current boot (default: the boot of the newest entry) |
| `.lm/boot-timing` | data for `systemd-analyze` (see below) |
| `.lm/systemd/units/<unit>.state` | preset runtime state (see below) |

**Journal entries.** Each line is one object. Field values are strings (numbers
are accepted). Fields used:
- `__REALTIME_TIMESTAMP`: µs since the epoch, or for convenience a readable local time `2026-11-10 02:05:00`.
- `_BOOT_ID`: an entry without it belongs to the current boot.
- `PRIORITY`: `"0"`–`"7"`.
- `SYSLOG_IDENTIFIER` (or `_COMM`) and `_PID`.
- `_HOSTNAME` and `MESSAGE`.
- `_TRANSPORT=kernel`: these are the `-k` entries.

`-u` matches `_SYSTEMD_UNIT`, `UNIT` (systemd's own "Started x" lines),
`OBJECT_SYSTEMD_UNIT` and `COREDUMP_UNIT`. Everything the mock itself logs (job
messages, the stdout/stderr of started services, load errors) is appended to
`run/log/journal/runtime.json` and merged in by time.

**Preset state.** A level can make a unit look as if it already ran, by writing
`key=value` lines with the names `systemctl show` uses:
```
ActiveState=failed            # active|inactive|failed|activating|deactivating
SubState=failed               # running|exited|dead|failed|auto-restart|...
Result=exit-code
ExecMainPID=4242
ExecMainCode=exited           # exited|killed|dumped (or 1|2|3)
ExecMainStatus=203            # exit code, or signal number for killed/dumped
MainPID=0
NRestarts=3
StateChangeTimestamp=2026-11-10 02:55:00     # local time or @epoch
```
`status`, `is-active`, `show`, `list-units` and the rest then report it like a
real unit, for example `Active: failed (Result: exit-code) since …; 15min ago`
and `Main PID: 4242 (code=exited, status=203/EXEC)`.

**`.lm/boot-timing`**:
- Phase lines: `firmware|loader|kernel|initrd|userspace MS`.
- Unit lines: `UNIT ACTIVATING_MS ACTIVE_MS [after=a.service,b.target]`, in ms since userspace started.
- `after=` adds to the unit file's `After=`. Units need no unit file.

### What happens on start

`systemctl start` spawns a supervisor
(`python3 …/systemctl --lm-supervise UNIT --lm-root ROOT`, so the sandbox path
is in its command line). The supervisor runs `ExecStartPre=`, `ExecStart=`,
`ExecStartPost=` as real background processes. In more detail:

- **Executables.** Executables are looked up in the fake root. `/bin`, `/usr/bin`, `/sbin` and `/usr/sbin` paths fall back to the host, so `/bin/sh -c …` works. Arguments that name an existing fake-root path are rewritten to the sandbox path.
- **Process environment.**
  - cwd is the fake root, or `WorkingDirectory=`.
  - Environment: `Environment=`, then `EnvironmentFile=`, which overrides it as in real systemd. The `-` prefix makes a file optional. `\r` ends a line.
  - Also set: `$LM_ROOT`, `$MAINPID` (for `ExecReload=`/`ExecStop=`), and `USER`/`HOME` from `User=`.
- **Output.** stdout/stderr go to the journal, or to `StandardOutput=file:/append:/truncate:/null`.
- **Process group and cleanup.**
  - Each process gets its own process group (its "cgroup"). When the main process exits, leftover processes in that group are killed (`KillMode=control-group`).
  - On Linux the supervisor is a subreaper and children die with it, so the engine's `pkill -f $SANDBOX` cleans up even after `exec sleep`.
- **Failures** are logged with systemd's messages: a missing or non-executable binary gives `status=203/EXEC`, a missing `WorkingDirectory` `200/CHDIR`, an unknown `User=` `217/USER`, a missing env file `Result: resources`.
- **Service types.**
  - `Type=simple` (also `notify`, `dbus`, `idle`): `start` returns 0 as soon as the process is forked, even if it fails right after, like real systemd.
  - `Type=exec`, `oneshot` and `forking` (`PIDFile=` or the remaining process) report failures as `Job for x failed because …`.
- **Restart policy.** `Restart=` (`no`, `on-success`, `on-failure`, `on-abnormal`, `on-abort`, `always`), `RestartSec=` (default 100ms), `RestartPreventExitStatus=`, `SuccessExitStatus=`, `StartLimitIntervalSec=`/`StartLimitBurst=` (default 10s/5, in `[Unit]` or `[Service]`). `NRestarts` and `start-limit-hit` behave as in systemd. `$LM_TIMESCALE` scales every wait.
- **Unit loading.**
  - A unit is loaded the first time any tool uses it, and kept until `daemon-reload`. After that, an edited file gives systemd's warning: "changed on disk. Run 'systemctl daemon-reload'". `systemctl cat` also prints the "# Warning: … changed on disk" header.
  - **End setup.sh with `./systemctl daemon-reload`** if it calls the mock before it finishes writing units.
  - `enable`, `disable`, `mask`, `unmask`, `set-default` reload by themselves.
  - A unit is `bad-setting` (refuses to start) when:
    - it has two `ExecStart=` without an empty reset line, unless `Type=oneshot`;
    - `ExecStart=` is relative (`./run.sh`) or an unknown bare name;
    - it has no `ExecStart=`.
- **Links.** Symlinks are absolute, exactly as systemd writes them (`multi-user.target.wants/x.service → /etc/systemd/system/x.service`, mask `→ /dev/null`, `default.target → /usr/lib/systemd/system/multi-user.target`). In the sandbox they dangle, so validators should use `readlink`, not `-e`.
- **Built-in targets.** `multi-user.target`, `graphical.target`, `basic.target`, `network(-online).target` and friends exist without unit files (shown as `/usr/lib/systemd/system/…`). Targets in the default target's tree count as active.

### systemctl

Verbs:
- Start and stop: `start`, `stop`, `restart`, `try-restart`, `reload`, `reload-or-restart`, `try-reload-or-restart`, `kill [-s SIG] [--kill-whom=main|all]`, `reset-failed`.
- Queries: `status [-n N]` (no unit: short overview), `is-active`, `is-enabled`, `is-failed`, `is-system-running`, `show [-p A,B] [-P A] [--value] [--all]`, `cat`.
- Unit files: `enable [--now] [--runtime]`, `reenable`, `disable [--now]`, `mask [--now]`, `unmask`, `daemon-reload`, `daemon-reexec`, `set-property UNIT Prop=…` (resource-control properties only; writes `etc/systemd/system.control/UNIT.d/50-Prop.conf`, bytes for `Memory*`, applied without a reload; `--runtime` writes under `run/`), `get-default`, `set-default`.
- Listings: `list-units [PATTERN] [--all] [--failed] [--state=] [-t TYPE] [--plain] [--no-legend]`, `list-unit-files [PATTERN] [--state=] [-t TYPE]`, `list-dependencies [UNIT] [--reverse] [--all]`.
- Dependencies when starting:
  - `start` pulls in `Requires=`, `Wants=` and `BindsTo=` units, plus `.wants/` and `.requires/` links. They start in `After=`/`Before=` order; unordered units start alphabetically, since systemd starts them in parallel with no order.
  - Targets implicitly come after what they pull in. Services come after `basic.target`.
  - `Conflicts=` units are stopped.
  - A failed `Requires=` dependency with `After=` gives `Dependency failed`. `Requisite=` is checked.
  - `stop` and `restart` also stop units that have `Requires=`, `BindsTo=` or `PartOf=` on the unit.
  - Ordering cycles are logged as in systemd ("Found ordering cycle …", "Job … deleted to break ordering cycle …").
- Exit codes: `start` of an unknown unit 5, masked 1, bad-setting 1; `status` 0/3/4; `is-active` 0/3; `is-enabled` 0/1.
- **`systemctl mock-boot [TARGET]`** (mock-only, for validators): stops everything, resets the runtime state and "boots" the default target (or TARGET). It prints console lines (`[  OK  ] Started …`, `[  OK  ] Reached target …`, `[FAILED] …`, `[DEPEND] …`) and exits 1 if any unit failed or ended up failed.
- Options ignored: `--no-pager -l --full -q --system --no-ask-password --no-block`.
- Real verbs that are not implemented (`isolate`, `edit`, `list-timers`, `reboot`, …) print `mock: systemctl VERB is not supported`. Unsupported options (`--user`, `-H`, `--root`, `-o`, …) print `mock: option X not supported`.

### journalctl

- Filters:
  - `-u/--unit` (globs, `x@inst`), `-t/--identifier`, `-T`, `FIELD=VALUE` matches (`+` for OR).
  - `-p/--priority` (`err`, `3`, `warning..err`).
  - `-S/--since` and `-U/--until` take systemd time formats: `2026-11-10 03:00[:00]`, `03:00`, `today`, `yesterday`, `tomorrow`, `now`, `-1h`, `+5min`, `1h 30min ago`, `@epoch`, ISO with `Z`/`+03:30`, a trailing zone name, a leading weekday. Combinations like `"yesterday 10:00"` are rejected as in systemd.
  - `-b [0|-1|N|BOOT_ID]`, `--list-boots`, `-k/--dmesg` (implies `-b`), `-g/--grep` (Python regex; case-insensitive when the pattern is all lowercase; `--case-sensitive`).
- Output: `-n N` (default 10, `all`, `+N`), `-r`, `-e` (= `-n 1000`), `-o short|short-precise|short-iso|short-iso-precise|short-full|short-unix|short-monotonic|cat|json|json-pretty|verbose`, `--utc`, `--no-hostname`, `-q`, `-F FIELD`, `-N`, `--file=PATH` (a JSON-lines file), `--disk-usage`.
- Formatting:
  - Times are shown in the fake root's time zone.
  - Boot changes print `-- Boot ID --`.
  - No match prints `-- No entries --`.
  - A bad timestamp prints `Failed to parse timestamp: X` (exit 1).
- `-f/--follow`, `--user`, `--vacuum-*` and the other real options print `mock: option X not supported`.

### systemd-analyze

- `time`, `blame` and `critical-chain [UNIT]` come from `.lm/boot-timing`. The critical chain uses systemd's algorithm: per level, the `After=` dependency that became active last. Without the file they fail with "Bootup is not yet finished …" (exit 1).
- `verify FILE|UNIT…` reports:
  - unknown keys and sections;
  - unparsable `Type=`/`Restart=`;
  - relative or unfound `ExecStart=` (fatal);
  - multiple `ExecStart=` (fatal);
  - commands that aren't executable (`Command /x is not executable: No such file or directory`);
  - `Requires=`/`BindsTo=` on missing units.

  It exits 1 on errors.

### timedatectl

- `status` (default), `show` and `list-timezones` use the frozen clock and the fake root's zone.
- `set-timezone ZONE` writes `etc/timezone` and the `etc/localtime` link, and rejects unknown zones like systemd does.

### Environment variables

`LM_ROOT`, `LM_NOW`, `LM_TZ`, `LM_HOSTNAME`, `LM_JOURNAL` (colon-separated JSON
files instead of the journal dirs), `LM_BOOT_TIMING`, `LM_TIMESCALE`.

### Notes for level authors

- These follow real systemd and differ from some curriculum drafts:
  - **`EnvironmentFile=` overrides `Environment=`**, not the other way round.
  - systemd's env-file parser treats `\r` as a line end, so a CRLF env file still gives `PORT=8080`.
  - `mask` refuses when the unit file itself is in `/etc/systemd/system` ("File … already exists"), so put vendor units in `usr/lib/systemd/system`.
- The clock is frozen. Everything the mock logs gets the frozen time, and `status` shows `since …; now` for units it started.
- Validators can read:
  - `./systemctl show -P MainPID|ActiveState|Result|NRestarts|MemoryMax x`;
  - the env the service really got: `LMEnvironment=` in `.lm/systemd/units/x.service.state` (JSON), or `/proc/PID/environ` on Linux;
  - the runtime journal.
- `LM_TIMESCALE` is read by the `systemctl` call that starts a unit (its supervisor keeps it). So `LM_TIMESCALE=0.01 ./systemctl mock-boot` in a validator replays a slow crash/restart pattern quickly.

## accounts/ — useradd, usermod, userdel, groupadd, groupmod, groupdel, gpasswd, passwd, chage, id, groups, getent

One Python 3 stdlib program, `accounts/accounts-mock`. The twelve tool names are
symlinks to it. Behaviour, messages and exit codes follow shadow-utils 4.13
(Ubuntu 24.04), coreutils `id`/`groups` and glibc `getent`. It keeps module 7's
behaviour (Ubuntu defaults, `usermod -G` without `-a` replaces). Tests:
`tests/test_mocks_accounts.py`. Used by modules 12, 16 (21), 23 (23), 26 (13).

### Shipping it

```bash
M="$(dirname "$0")/../../../mocks"
mkdir -p "$SANDBOX/bin"
for t in useradd usermod gpasswd chage; do cp "$M/accounts/$t" "$SANDBOX/bin/"; done
```

The fake root is found as for the systemd mocks: `$LM_ROOT`, else the tool's
directory with a trailing `bin/` skipped. So `$SANDBOX/bin/useradd` edits
`$SANDBOX/etc/passwd`. The player runs `bin/useradd …`.

### Files

| path in the fake root | notes |
|---|---|
| `etc/passwd`, `etc/group` | required for most tools; written in place, untouched lines stay byte-identical (comments and NIS `+`/`-` lines included) |
| `etc/shadow`, `etc/gshadow` | updated only if present (useradd adds `user:!:TODAY:0:99999:7:::` and `user:!::`) |
| `etc/subuid`, `etc/subgid` | if present, `useradd` gives non-system users the lowest free `SUB_*_COUNT` range ≥ `SUB_*_MIN` that overlaps nothing (unsorted files and odd counts handled) |
| `etc/login.defs` | `UID_MIN/MAX`, `SYS_UID_MIN/MAX`, `GID_*`, `PASS_MIN_DAYS/MAX_DAYS/WARN_AGE`, `USERGROUPS_ENAB`, `HOME_MODE`, `UMASK`, `CREATE_HOME`, `SUB_UID_*`; without the file, Ubuntu 24.04's values (1000–60000, 100–999, 0/99999/7, `HOME_MODE 0750`) |
| `etc/default/useradd` | `SHELL` (default `/bin/sh`), `HOME`, `GROUP`, `SKEL`, `INACTIVE`, `EXPIRE` |
| `etc/skel/` | copied with modes, dotfiles and subdirs by `useradd -m` (homes are created under the fake root; no chown) |
| `.lm/now` (or `LM_NOW`), `etc/timezone` (or `LM_TZ`) | "today" for shadow's last-change field and chage dates |

### Tools

- **useradd** `-m -M -s -c -d -b -g -G -u -o -r -N -U -e -f -p -k -K -l --badname`, `-D` (print only).
  - Allocation as in shadow 4.13:
    - normal UIDs: highest used in range + 1;
    - system UIDs: lowest used system ID − 1, counting down from `SYS_UID_MAX`;
    - private group: GID = UID if that is free, else allocated the same way.
  - With `-m`: home mode `HOME_MODE`. An existing home gives the two "already exists / Not copying" warnings.
  - Messages and exit codes: exists 9, bad name 3 (`… use --badname to ignore`), unknown group 6, UID not unique 4, `group X exists - … use -g.` 9.
  - A missing shell gives the 4.13 warning, but only when the fake root contains a captured system tree.
- **usermod** `-a -r -G -g -s -c -d [-m] -l -u [-o] -L -U -e -f -p -b -v/-V/-w/-W` (subuid/subgid ranges).
  - `-G` without `-a` replaces the supplementary groups in group and gshadow.
  - `-L` prefixes `!` once. `-U` refuses to leave a passwordless account.
  - `-e 1`/`-e ''` set or clear the expiry field.
  - `-l` renames in passwd, shadow and the member and admin lists.
  - An option that changes nothing prints `usermod: no changes`.
  - `-a` without `-G` prints the error plus the usage text (exit 2).
- **userdel** `[-r] [-f]`: removes the user from passwd, shadow, the member lists, subuid and subgid, plus their private group when it is unused.
  - `-r` removes the home (only inside the fake root) and prints `userdel: X mail spool (/var/mail/X) not found` like Ubuntu.
- **groupadd** `-g -r -f -o -p -U -K`.
- **groupmod** `-n -g` (also moves users whose primary GID was the old one), `-U [-a]`, `-p`, `-o`.
- **groupdel** `[-f]`: refuses a user's primary group (exit 8).
- **gpasswd** `-a USER`, `-d USER` (prints `Adding/Removing user X to/from group G`), `-M a,b`, `-A a,b`, `-r`, `-R`.
  - Edits both group and gshadow and leaves no stray commas.
  - Errors exit 3.
- **passwd** `-S [-a]` (`user P|L|NP YYYY-MM-DD min max warn inact`), `-l`, `-u`, `-d`, `-e`, `-n -x -w -i`, `-q`.
  - Changes print `passwd: password expiry information changed.`
  - Setting a password interactively is not supported.
- **chage** `-l [-i]` (exact shadow-utils layout, tabs included: "password must be changed", "never", `Mon DD, YYYY`), `-d -E -I -m -M -W` (dates as `YYYY-MM-DD` or days, `-1` clears).
- **id** `[-u|-g|-G] [-n] [-z] [USER|UID]`: the primary group first, then supplementary groups in etc/group order, as `getgrouplist()` gives them.
- **groups** `[USER…]`.
- Without a user, `id` and `groups` look up the current login in the fake passwd. If it isn't there, they run the real `/usr/bin/id` or `/usr/bin/groups`.
- **getent** `passwd|group|shadow|gshadow [KEY…]`: keys are names, or UID/GID numbers for passwd and group. A missing key exits 2. Other real databases (`hosts`, …) print `mock: getent database 'X' not supported`.

Options of the real tools that make no sense here (`-R/--root`, `-P/--prefix`,
`-Z`, …) print `mock: option X not supported` (exit 2).

## packages/ — a Debian package world on the real apt and dpkg

`pkgsim.py` builds a self-contained package system inside the sandbox and installs
wrappers with the real names (`apt`, `apt-get`, `apt-cache`, `apt-mark`, `apt-config`,
`apt-key`, `dpkg`, `dpkg-query`) into `$SANDBOX/bin`. Each wrapper runs the **real**
program pointed at the sandbox, as a normal user, offline. Nothing is re-implemented:
`apt-get install/remove/purge/upgrade`, `apt update`, `apt-mark hold`, `dpkg -i/-r/-P/-V/-S/-L`,
`dpkg --set-selections`, `apt-cache policy/madison/rdepends` all really run, with apt's
own dependency resolution, messages, exit codes, `var/log/apt/history.log`, `term.log`
and `var/log/dpkg.log`. Linux only: it needs dpkg, dpkg-deb, apt (and gpgv for signed
repos), which are all in the reference image. Tests: `tests/test_mocks_packages.py`.

How it works: `rootfs/etc/apt/apt.conf` (which the wrappers export as `APT_CONFIG`) points
every `Dir::` at the sandbox root, turns off locking, and makes apt call
`dpkg --root=ROOT --force-not-root --force-bad-path --force-script-chrootless --path-include=/*`.
Repositories are local `file:` archives with real `.deb` files built by `dpkg-deb`, plus
`Packages(.gz)` and `Release` indexes, and optionally `InRelease`/`Release.gpg` signed by
`pgp.py` (only `gpgv` exists at runtime, see below). The one simulated part is apt's
`Do you want to continue? [Y/n]` prompt, because the game's shell can't answer it. When
output goes to a terminal, the `apt`/`apt-get` wrapper answers it (`Y`, or `$LM_APT_ANSWER`)
and prints the answer as if typed, and adds the ` Done` that apt prints after "Reading
package lists..." on a terminal. Without a terminal (validators, pipes), the real apt
runs untouched: it answers from stdin and aborts on EOF.

### Building it from setup.sh

```bash
SANDBOX="$1"
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
cat > "$SANDBOX/.fixture.json" <<'EOF'
{ "repos": [ {"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "sign": "key3",
              "packages": [ {"name": "fluxd", "version": "3.2.0-1", "depends": "libflux1 (>= 1.5)"},
                            {"name": "fluxd", "version": "3.1.4-1", "depends": "libflux1 (<< 1.5)"},
                            {"name": "libflux1", "version": "1.5.0-1"},
                            {"name": "libflux1", "version": "1.4.2-1"} ] } ],
  "installed": [ {"name": "libflux1", "version": "1.5.0-1"} ] }
EOF
python3 "$MOCKS/packages/pkgsim.py" build "$SANDBOX" "$SANDBOX/.fixture.json" || exit 1
rm "$SANDBOX/.fixture.json"
```

`pkgsim.py build SANDBOX FIXTURE.json [--no-update] [--repos-only]` exits 1 with a message
if the fixture is wrong. By default it ends with a real `apt-get update`, so `apt-cache`
works at once. `--no-update` skips that step. `--repos-only` only rebuilds the repository
directories (and keyrings) from a new fixture: the installed system and the apt lists stay
as they were. It's for "the vendor published 2.4.1, make apt see it" levels: build v1,
then rebuild with `--repos-only --no-update` so the player has to run `apt update`.
400 packages with real `.deb`s take about 1.5 s.

The engine does not put `$SANDBOX/bin` on the player's `PATH`. Say in the objective that
the sandbox's package tools are in `bin/` (`bin/apt install ...`), or have the hint start
with `export PATH="$SANDBOX/bin:$PATH"`. The system's own `/usr/bin/apt-get` fails as a
normal user (no root), so a player who forgets gets a real permission error, not a wrong
success. Package files land under `$SANDBOX/rootfs` (configurable), e.g.
`rootfs/etc/fluxd/fluxd.conf`, `rootfs/var/lib/dpkg/status`.

**Validators** can call the real tools directly, without trusting anything the player can
edit in `bin/`:
`dpkg-query --root="$SANDBOX/rootfs" -W -f='${db:Status-Abbrev} ${Package} ${Version}\n'`,
`APT_CONFIG="$SANDBOX/rootfs/etc/apt/apt.conf" apt-cache policy fluxd`,
`APT_CONFIG=... apt-get -s upgrade` (prints a "NOTE: This is only a simulation!" banner
as non-root), `dpkg --root="$SANDBOX/rootfs" -V`. They can also read
`rootfs/var/log/apt/history.log` to check what the player actually ran.

### Fixture format (JSON)

| key | meaning |
|-----|---------|
| `root` | the fake `/`, relative to the sandbox (default `rootfs`) |
| `bin` | where the wrappers go (default `bin`); the code is copied to `bin/.mocks/packages/` |
| `arch` | `native` (default: the host's `dpkg --print-architecture`, amd64, or arm64 on Apple-silicon Docker) or a name. Packages default to it. Validators must not hard-code `amd64`. |
| `date` | `"YYYY-MM-DD HH:MM:SS"`, the `Date:` of every Release file, and the signature time (default `2024-04-01 12:00:00`). No `Valid-Until` is written, so fixtures never expire. |
| `repos` | list of repositories (below) |
| `installed` | packages installed into `rootfs` with the real `dpkg -i` (below) |
| `base_files` | default `true`: also installs a `base-files 13ubuntu10` that owns `/etc`, `/usr/bin`, `/usr/share/doc` ... as on a real system, so removing a package doesn't warn "directory '/usr/bin' not empty so not removed" |
| `links` | `{"/bin": "usr/bin"}`: symlinks made in the root before installing (usrmerge) |
| `keyrings` | `{"/etc/apt/keyrings/vendor.gpg": {"key": "key2", "uid": "Vendor <v@vendor.example>"}}`, a value may be a list of keys; `.asc` paths (or `"armor": true`) are ASCII-armoured |
| `files` | `{"/etc/apt/preferences.d/10-pin.pref": "text", ...}`: extra files written **after** installing (file spec below), so this also edits or tampers with installed files |
| `remove_files` | list of root paths deleted after installing (a "missing file" for `dpkg -V`) |
| `history` | entries appended to `var/log/apt/history.log`: `{"start": "2024-03-01 10:00:00", "end": ..., "commandline": "apt-get install x", "requested_by": "admin (1000)", "install": ["x:amd64 (1.0-1)"], "upgrade": [...], "downgrade", "remove", "purge", "reinstall", "error"}` (strings are written as given) |
| `update` | `true` (default): run `apt-get update`, fail on any `W:`/`E:`; `"try"`: run it and accept errors; `false`: don't |

**Repository**:

| key | meaning |
|-----|---------|
| `name` | unique id (default: the suite): directory `repos/<name>/`, sources file `<name>.list`/`.sources`, default keyring name |
| `path` | directory relative to the sandbox (default `repos/<name>`) |
| `suite`, `codename`, `origin`, `label`, `version`, `description` | Release fields (`a=`, `n=`, `o=`, `l=`, `v=` for pinning). Defaults: `stable`, the suite, `LinuxMissions` |
| `components` | default `["main"]`; a package picks one with `"component"` |
| `not_automatic`, `but_automatic_upgrades` | `NotAutomatic: yes` / `ButAutomaticUpgrades: yes`, as in Ubuntu backports (apt priority 100) |
| `sign` | test key name (`key1`..`key4`): writes `InRelease` and `Release.gpg`; `sign_time` overrides the time (epoch) |
| `signed_by` | root path of the keyring for the sources entry. Default for signed repos: `/etc/apt/keyrings/<name>.gpg`, created automatically. `null`: no `signed-by` (the key must then be in `trusted.gpg.d`) |
| `trusted` | add `[trusted=yes]` (default: true for unsigned repos, false for signed ones) |
| `sources` | `list` (default: `etc/apt/sources.list.d/<name>.list` one-line), `deb822` (`<name>.sources`), `main` (`etc/apt/sources.list`), `none` (write your own) |
| `sources_file` | file name override |
| `uri_scheme` | `file` (default) or `copy` (apt copies the debs into `var/cache/apt/archives`) |
| `debs` | `true` (default) builds real `.deb`s. `false` writes the index only (fast, for search levels): `apt-cache` works, installing fails with apt's real "File not found" |
| `packages` | list of package specs |

Sources entries use absolute paths (`deb [signed-by=/tmp/linuxmissions/<level>/rootfs/etc/apt/keyrings/x.gpg] file:/tmp/linuxmissions/<level>/repos/x noble main`),
because apt needs real paths. Hints should show `$SANDBOX/...` and use double quotes.

**Package spec** (in a repo, or in `installed` with `"local": true` for a package that is in
no repo; local `.deb`s are kept in `rootfs/var/cache/apt/archives/`):

| key | meaning |
|-----|---------|
| `name`, `version` | required; version is any Debian version (`1:2.0~rc1-1ubuntu2`) |
| `arch` | `native` (default) or `all` |
| `depends`, `pre_depends`, `recommends`, `suggests`, `enhances`, `conflicts`, `breaks`, `replaces`, `provides` | control fields, verbatim (`"libx1 (>= 1.2) \| liby1"`) |
| `section`, `priority`, `maintainer`, `homepage`, `source`, `multi_arch`, `essential` | control fields (defaults `misc`, `optional`, `Example Packagers <packages@example.org>`) |
| `description` | first line = synopsis, more lines = long description (blank line → ` .`) |
| `installed_size` | KiB; default computed from the files |
| `fields` | extra control fields `{"X-Origin": "..."}` |
| `files` | `{"/usr/bin/x": "content", ...}`, default: just `/usr/share/doc/<name>/copyright` |
| `scripts` | `{"postinst": "#!/bin/sh\n..."}`: maintainer scripts run for real, chrootless. They must use `"$DPKG_ROOT"` in front of every path. |
| `component` | the repo component (default its first) |

A **file spec** is a string (content), or `{"content": "...", "mode": "0755", "conffile": true}`,
`{"gzip": "text"}` (stored gzip-compressed, e.g. `changelog.Debian.gz`), `{"base64": "..."}`,
`{"symlink": "target"}`, or `{"dir": true}` (also: a path ending in `/`). Files under `/etc/`
are conffiles unless `"conffile": false`, as with debhelper. Files under `bin/`/`sbin/`
default to mode 0755. `md5sums` are generated, so `dpkg -V` works.

**Installed spec**: `{"name": "x"}` (newest version found in the repos), `{"name": "x", "version": "1.0-1"}`,
a bare `"x"`, or a full local spec. Options: `"auto": true` writes `Auto-Installed: 1` to
`var/lib/apt/extended_states` (`apt-mark showauto`, `autoremove`). `"state"` is the
`dpkg -l` abbreviation: `ii` (default), `rc` (removed, conffiles left), `hi` (held),
`iU` (unpacked), `iF` (half-configured), `iH`, `iW`, `it`, `pn`, ..., with an optional
third letter `R` (reinst-required). Everything is installed with the real dpkg
(`--force-depends`, so a fixture may be broken on purpose); exotic states are then
written into the status file. A level that needs a captured `status` file verbatim
(module 20 level 7, module 26 package-panic) can still overwrite
`rootfs/var/lib/dpkg/status` after building.

### Signing keys (pgp.py)

`gpg` is not in the image, only `gpgv`. `pgp.py` is a small stdlib OpenPGP signer: RSA-3072,
v4 signatures, SHA-512, accepted by gpgv and apt. The keys in `packages/keys/` are **test
keys whose secret parts are committed on purpose**, so any level can sign its own
repository at setup time. Nothing else may trust them.

| key | fingerprint | created |
|-----|-------------|---------|
| key1 | `318A4D8BED9ED33AA2CA1A756032EBC36CBCED57` | 2020-01-01 |
| key2 | `3493CB32905056D759665382AD8E476A51178E68` | 2022-01-01 |
| key3 | `4483D3CAA951841C155483CD2C5D758F8966854A` | 2024-01-01 |
| key4 | `8486E7EA36711750B9BB6C4AB9FF70DC34EB2F85` | 2024-06-01 |

The user ID is chosen when exporting, so the same key can be "Vendor archive key 2024"
in one level and something else in another.

```
python3 pgp.py list | fingerprint KEY
python3 pgp.py export KEY [--uid "Vendor <a@vendor.example>"] [--armor] > keyring.gpg
python3 pgp.py clearsign KEY FILE [--time EPOCH] > InRelease
python3 pgp.py sign KEY FILE [--armor] [--time EPOCH] > FILE.sig     # detached, for promote.sh-style gates
gpgv --keyring ./keyring.gpg FILE.sig FILE                           # what the player runs
```

Key rotation (module 20 level 11): sign the repo with `key3`, and put `key2` ("old vendor key")
and `key3` in two keyring files under `keyrings/`, and an unrelated `key4` in a third. A source
whose `signed-by` names the wrong file gets apt's real
`NO_PUBKEY 2C5D758F8966854A` warning and keeps the old lists.

### Environment and limits

- `APT_CONFIG`: set by the wrappers. Unset it (or use the real paths) to reach the
  system's apt.
- `LM_APT_ANSWER`: the answer the wrapper gives to apt's prompt on a terminal (default `Y`).
- Only `file:`/`copy:` repositories (no network). `apt-key add` and `apt-key list` fail
  with apt's real "gnupg ... not installed" error. `apt-get source`/`build-dep` have no
  deb-src. Timestamps in the logs are the real time. `sudo` is not part of the mock.
- With `uri_scheme: file` apt reads the debs in place and `var/cache/apt/archives`
  stays empty.
- Curriculum note (module 20): the curriculum's mock `sapt` is not needed. The real
  `apt-get install` works in the sandbox. A `-y` install that downgrades needs
  `--allow-downgrades`, exactly as on a server.
- Several repositories may share one mirror directory (one `path`, several suites).
  Details and recipes: `packages/NOTES.md`.

## cron/ — crontab, cron-run, cron-expand, run-parts, OnCalendar

Debian cron 3.0pl1 as in Ubuntu 24.04, ported from its C source so field parsing, error
messages (including their line numbers), environment lines and `%` handling match. Python 3
stdlib, Linux and macOS. Tests: `tests/test_mocks_cron.py` (they also compare with the real
`run-parts`, `systemd-analyze calendar` and, on x86_64, `crontab -n`).

| file | what |
|------|------|
| `cronlib.py` | the parser and semantics (import it from validators) |
| `crontab` | mock `crontab(1)` that keeps tables in a sandbox spool |
| `cron-run` | runs jobs from a sandbox's crontabs for a simulated time window, with logs |
| `cron-expand` | lists when lines fire in a window (for validators and players) |
| `run-parts` | mock `run-parts(8)` (debianutils rules), for macOS and for `cron-run` |
| `oncalendar.py`, `systemd-analyze` | systemd `OnCalendar=` parser and a `systemd-analyze calendar` mock |
| `install.sh` | copies the tools into a sandbox and writes wrappers |

### Semantics (what cronlib implements)

- Fields: minute 0-59, hour 0-23, day-of-month 1-31, month 1-12 or `jan`..`dec`,
  day-of-week 0-7 or `sun`..`sat` (0 and 7 are Sunday). Names have exactly 3 letters, any
  case. Lists `1,5`, ranges `1-5`, steps `*/15`, `1-30/10`. A reversed range `5-1` is accepted
  and selects **nothing**. A step without a range (`5/10`) is an error. A step larger than
  the range prints `Warning: Step size ...`.
- The day rule: if day-of-month **or** day-of-week starts with `*`, both must match;
  otherwise the job runs when **either** matches. A field like `*/2` counts as starting with
  `*`, so `0 2 */2 * 1` means odd days that are also Mondays.
- `@reboot @yearly @annually @monthly @weekly @daily @midnight @hourly`.
- `NAME = value` lines (quotes optional, trailing blanks trimmed even inside quotes). They
  apply to the job lines after them. `MAILTO=` with nothing after it is **not** an
  environment line (it is a "bad minute"); `MAILTO=""` is.
- `%`: the first unescaped `%` ends the command, the rest goes to stdin with `%` → newline
  (and a final newline). `\%` → `%`.
- System crontabs (`etc/crontab`, `etc/cron.d/*`) have a user field. `cron.d` file names must
  match `^[A-Za-z0-9_-]+$` (so `old.conf.dpkg-old` and `backup.sh` are ignored). A crontab
  with any syntax error is ignored entirely, and a missing final newline refuses the file.
- Install errors are crontab's: `"FILE":N: bad minute` / `errors in crontab file, can't install.`.
  As in Debian, N is the line number minus one for errors in the time fields (`:0:` for line 1).
  These are the amd64 messages. Ubuntu's real `crontab` on arm64 reports most field errors as
  "bad command", because of a `char` signedness bug.

### Installing into a sandbox

```bash
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
bash "$MOCKS/cron/install.sh" "$SANDBOX" --user deploy crontab        # tools: crontab cron-run cron-expand run-parts systemd-analyze
LM_CRON_USER=alice "$SANDBOX/bin/crontab" "$SANDBOX/.alice.cron"         # seed another user's table (with --privileged, or as that user)
```

`install.sh SANDBOX [--bin DIR] [--spool DIR] [--user NAME] [--privileged] [--now "YYYY-MM-DD HH:MM"] [TOOL...]`
copies the code to `BIN/.mocks/cron/` and writes one wrapper per tool to `BIN` (default
`$SANDBOX/bin`). The wrappers set defaults the caller can override:

| variable | meaning |
|----------|---------|
| `LM_CRON_SPOOL` | user crontab directory (default `$SANDBOX/var/spool/cron/crontabs`), one file per user, mode 0600 |
| `LM_CRON_USER` | the login name the player acts as (default `$USER`) |
| `LM_CRON_PRIVILEGED` | `1`: act as root, so `crontab -u anyone` works (otherwise "must be privileged to use -u") |
| `LM_CRON_NOW` | frozen time for the crontab header and the default `--from` of cron-run / cron-expand |

As with the package tools, the player must call `bin/crontab` (or put `$SANDBOX/bin` first
in PATH). Say so in the objective. On macOS the system `crontab` would edit the player's real
crontab. In Docker the real one writes the container's spool, which no validator reads. The
engine already opens `crontab -e` on the real terminal, so `$EDITOR` works.

**crontab mock**: `crontab [-u user] [-n] file|-` (no argument = stdin), `-l`, `-r`, `-i -r`, `-e`,
`-h`, with crontab's usage text, messages and exit codes (`no crontab for deploy`, `crontab:
installing new crontab`, `No modification made`, `Do you want to retry the same edit? (y/n)`,
`edits left in /tmp/crontab.XXXX/crontab`). Like Debian it stores a 3-line `# DO NOT EDIT THIS
FILE` header in the spool file, which `-l` hides (`CRONTAB_NOHEADER=N` shows it). A new table
edited with `-e` starts with Debian's help comment. A spool file that setup writes directly
should have no leading comment lines, or `crontab -l` hides up to three of them. Use the mock
to install it, or start the file with `cronlib.make_header()`. `-x` is "mock: not supported".
At end of input, the y/n questions count as "no".

### cron-run (run the clock)

```
cron-run --root DIR [--from T] (--to T | --days N | --at T) [--jsonl F] [--log F] [--summary] [--list]
         [--crontab FILE[:USER]]... [--system-crontab FILE]... [--spool DIR] [--no-periodic]
         [--home DIR] [--path P] [--boot] [--tick S] [--timeout S] [--mail-dir DIR] [--no-clock] [-q]
```

It reads what cron would: `DIR/etc/crontab`, `DIR/etc/cron.d/*` (name rules apply), the
spool's user tables. If `DIR/etc/crontab` doesn't exist, it adds Ubuntu's defaults for
`DIR/etc/cron.{hourly,daily,weekly,monthly}`: `17 * * * *`, `25 6 * * *`, `47 6 * * 7`,
`52 6 1 * *`, as `cd / && run-parts --report DIR/etc/cron.X`. A sandbox `etc/crontab` is run
as written, so it must name sandbox paths. Every job due in `[from, to)` (times
`"YYYY-MM-DD HH:MM"`) **really runs**: `SHELL -c CMD` with cron's environment (`SHELL=/bin/sh`,
`PATH=/usr/bin:/bin`, `HOME`, `LOGNAME=<user>`, plus the crontab's `NAME=value` lines), cwd =
`$HOME` (default the sandbox), stdin = the `%` text. Jobs run as the player; the crontab
user is only a name. Jobs in one file start in reverse file order, as cron does.

- **Clock**: jobs see the simulated time through a `date` shim first in their `PATH`
  (`$PATH` therefore starts with a `cron-run-clock.*` directory, then the real value; the
  JSONL `env` shows the value cron would set). `date -d/-r/-f/-s` and `/bin/date` by absolute
  path see the real clock, as do other tools (`find -mtime`, `touch`). `--no-clock` turns the
  shim off.
- **Overlap**: `--tick 0` (default) runs jobs one after another. `--tick S` makes S real
  seconds = one simulated minute and runs jobs concurrently, so a job that takes longer than
  its interval really overlaps the next run (for `flock -n` levels). Idle time is skipped.
- **Output**: stdout gets cron's syslog lines, `Apr  8 02:00:01 sandbox CRON[1003]: (deploy) CMD (cmd)`,
  plus `(user) ERROR (Syntax error, this crontab file will be ignored)` for a broken table.
  `--log F` appends them to F. `--jsonl F` writes one object per run: `time` (scheduled,
  `YYYY-MM-DD HH:MM`), `user`, `source` (e.g. `var/spool/cron/crontabs/deploy`,
  `etc/cron.d/x`, `etc/cron.daily`), `line`, `schedule`, `command` (after `%` handling),
  `stdin`, `env`, `cwd`, `exit`, `output` (stdout+stderr), `mailto`, `mailed`, `killed`,
  `start`/`end` (real epoch seconds). `--summary` prints runs and exit codes per job. Exit
  status 1 if a table was ignored for errors.
- **Mail**: non-empty output goes to `MAILTO` (default the crontab's user; `MAILTO=""` = none)
  as an mbox message in `DIR/var/mail/<rcpt>` (or `--mail-dir`), with cron's headers
  (`Subject: Cron <deploy@sandbox> cmd`, `X-Cron-Env: <...>`). Without a mail dir it logs
  `(CRON) info (No MTA installed, discarding output)`.
- `--list` only prints `time<TAB>user<TAB>source:line<TAB>command`. `--boot` runs `@reboot`
  jobs at the start. `--timeout` (default 60 s) kills a job's process group and sets
  `killed: true`. `--path` changes the default PATH. Ubuntu's systemd unit starts cron with
  `-P`, so on a real 24.04 server jobs inherit
  `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`. The crontab(5) default
  `/usr/bin:/bin` is what the curriculum teaches, so it is the default here.

Validator example (module 15 level 18, "every run in 62 days"):

```bash
"$MOCKS/cron/cron-run" --crontab "$SANDBOX/backup.cron:backup" --from "2024-01-01 00:00" --days 62 \
  --no-periodic -q --jsonl "$TMP/runs.jsonl"
python3 -c 'import json,sys; [print(r["time"], r["command"].split()[-1]) for r in map(json.loads, open(sys.argv[1]))]' "$TMP/runs.jsonl"
```

### cron-expand and cronlib (fire times)

`cron-expand [--system] [--from T] [--to T | --days N] [--format FMT] [--times-only | --count | --json] [--check] FILE|-`
or `-e 'LINE' [-e 'LINE' ...]`. It prints `YYYY-MM-DD HH:MM<TAB>LINENO<TAB>COMMAND` per run,
ordered by time, and exits 1 (with crontab's messages) on a file crontab would refuse.
`--check` behaves like `crontab -n`.

From Python (validators: `sys.path.insert(0, MOCKS + "/cron")`):

```python
import datetime as dt, cronlib
tab = cronlib.parse_crontab(open(path).read(), system=False)   # .entries .env .errors .warnings .missing_newline
cronlib.check_install(text, "crontab.txt")                     # [] or crontab's error lines
e = cronlib.parse_line("0 3 1 * 0 /x")                          # raises cronlib.CronError
e.matches(dt.datetime(2024, 4, 7, 3, 0))                         # True (a Sunday)
runs = cronlib.expand(tab.entries, dt.datetime(2024, 4, 7), dt.datetime(2024, 4, 8))   # [(datetime, Entry)]
cronlib.split_command(r"date +\%F %body")                       # ('date +%F ', 'body\n')
cronlib.valid_crond_name("x.dpkg-old"), cronlib.run_parts_list("etc/cron.daily")
cronlib.parse_anacrontab(text)                                   # (env, jobs, errors) for anacrontab levels
```

An `Entry` has `minute hour dom month dow` (frozensets), `dom_star dow_star reboot`,
`command` (as written), `schedule` (time part as written), `user` (system tables), `env`,
`lineno`, `line`.

### run-parts mock

`run-parts [--test|--list] [--report] [-v] [--lsbsysinit] [--regex=RE] [--reverse] [--exit-on-error] [-a ARG] [-u UMASK] DIR`.
Default names are `^[A-Za-z0-9_-]+$` (no dots); `--lsbsysinit` uses debianutils' LSB rules.
Only executable regular files run, in C-locale order. `--report` prints `DIR/name:` before a
script's output. Errors are `run-parts: DIR/x exited with return code N`. The reference image
has the real one; this mock is for macOS players and for cron-run.

### OnCalendar (systemd timers)

The reference image has the real `systemd-analyze calendar`. It works as non-root. Use it in
validators on Linux. `oncalendar.py` is a port of systemd's calendarspec.c: normalized form,
next elapse and errors match systemd 255 for the forms timer levels use. The tests compare
it with the real one. Unsupported: `~` with ranges or repetitions ("mock: ...").

```python
import oncalendar
oncalendar.normalize("Mon-Fri 2:30")        # 'Mon..Fri *-*-* 02:30:00'
oncalendar.parse("*-*-* 25:00")             # ValueError('Invalid argument')
oncalendar.next_elapse("Mon..Fri 02:30", after=aware_datetime, n=3)
```

`bin/systemd-analyze` from `install.sh ... systemd-analyze` supports only
`calendar [--iterations=N] [--base-time=TIME] SPEC...`, with systemd's output
(`Original form`, `Normalized form`, `Next elapse`, `(in UTC)`, `From now`). Other verbs say
"mock: ... not supported". The systemd mock in `mocks/systemd/` has its own
`systemd-analyze` without `calendar`, so don't install both into the same `bin/`. A timer
level that needs both could call `oncalendar.py` from a level-specific wrapper.

Curriculum note (module 15 level 7): real systemd accepts `Mon-Fri` as an old spelling of
`Mon..Fri` (both normalize to `Mon..Fri *-*-* 02:30:00`). Only `daily` (which drops the
weekdays) is actually wrong there.

## security/ — sshd

`security/sshd` is a stand-in for OpenSSH's `sshd -T` / `-t` / `-f` / `-C user=,host=,addr=`:
first value wins, `Include` is expanded in place, `Match` blocks apply only with `-C`,
and output, defaults and exit codes follow Ubuntu's sshd. Full documentation, including
how to ship it from setup.sh: `security/README.md`. Used by module 16 (8, 22, 24).
