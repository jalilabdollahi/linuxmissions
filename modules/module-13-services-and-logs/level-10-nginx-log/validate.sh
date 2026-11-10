#!/bin/bash
# worst.txt = "path count max_upstream": among requests at 14:00:00 or later,
# the path (query string removed) with the most 5xx responses, how many, and
# the highest $upstream_response_time (last field) among those 5xx responses
# ("-" = no upstream, ignored). Recomputed from the access log.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/access.sum ] || ! cksum var/log/nginx/access.log 2>/dev/null | cmp -s - .lm-state/access.sum; then
  echo "❌ var/log/nginx/access.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f worst.txt ]; then
  echo "❌ worst.txt does not exist yet"
  exit 1
fi

python3 - <<'PY'
import re, sys
from collections import Counter, defaultdict

LINE = re.compile(r'^\S+ - \S+ \[10/Nov/2026:(\d\d:\d\d:\d\d) [+-]\d{4}\] "(\S+) (\S+) [^"]*" (\d{3}) \S+ "[^"]*" "[^"]*" (\S+) (\S+)$')
since, everything, by_url = Counter(), Counter(), Counter()
up_err, rt_err, up_all = defaultdict(float), defaultdict(float), defaultdict(float)
for line in open("var/log/nginx/access.log", encoding="utf-8"):
    m = LINE.match(line.rstrip("\n"))
    if not m:
        continue
    tm, method, url, status, rt, up = m.groups()
    path = url.split("?")[0]
    late = tm >= "14:00:00"
    if late and up != "-":
        up_all[path] = max(up_all[path], float(up))
    if not status.startswith("5"):
        continue
    everything[path] += 1
    if late:
        since[path] += 1
        by_url[url] += 1
        if up != "-":
            up_err[path] = max(up_err[path], float(up))
        rt_err[path] = max(rt_err[path], float(rt))

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

rows = [l.split() for l in open("worst.txt", encoding="utf-8", errors="replace").read().replace("\r", "").splitlines() if l.strip()]
if len(rows) != 1 or len(rows[0]) != 3:
    fail("worst.txt must be one line 'path count max_upstream', e.g. '/api/v2/example 12 1.234'")
path, count, mx = rows[0]
try:
    count, mx = int(count), float(mx)
except ValueError:
    fail("the count must be a whole number and max_upstream a number of seconds like 1.234")

best = max(since, key=lambda p: since[p])
if "?" in path:
    if by_url[path] == count:
        fail("that's one full URL; the same endpoint is called with many different query strings. Count by path, with the ?... part removed")
    fail("write the path without the query string")
if path != best:
    if path == max(everything, key=lambda p: everything[p]):
        fail(f"{path} had the most 5xx over the whole log, but most of them before the 14:00 deploy")
    if path in since:
        fail(f"{path} had {since[path]} 5xx responses since 14:00; another endpoint had more")
    fail(f"{path} is not the endpoint with the most 5xx responses since 14:00")
if count != since[best]:
    if count == everything[best]:
        fail(f"{count} counts {best}'s 5xx over the whole log; only 14:00:00 and later counts")
    fail(f"{best} is right, but {count} is not the number of its 5xx responses since 14:00 (503s count too)")
if abs(mx - up_err[best]) < 0.0005:
    print(f"✅ {best}: {since[best]} server errors since the deploy, worst upstream time {up_err[best]:.3f}s (the proxy_read_timeout is 30s)")
    sys.exit(0)
if abs(mx - rt_err[best]) < 0.0005:
    fail(f"{mx} is $request_time (the second-last field); the upstream response time is the last field")
if abs(mx - up_all[best]) < 0.0005:
    fail(f"{mx} comes from a successful request; the question is the worst upstream time among the 5xx responses")
fail(f"{mx} is not the highest upstream response time among {best}'s 5xx responses since 14:00")
PY
