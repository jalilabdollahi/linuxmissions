#!/bin/bash
# shop-web-1's nginx access log, 13:30 to 15:10 on Nov 10 (log_format in
# etc/nginx/nginx.conf: combined + $request_time $upstream_response_time).
# Since the 14:00 deploy users see errors. Answer: the path (without query
# string) with the most 5xx responses since 14:00, that count, and the highest
# $upstream_response_time among those 5xx. Planned per setup:
#  - the real winner's errors are spread over many ?id=/?q= query strings, so
#    counting whole URLs crowns /api/v2/checkout instead;
#  - /api/v2/cart had a bigger 5xx storm at 13:4x, before the deploy;
#  - the winner has 503s from limit_req with upstream "-", a slow 200 with a
#    bigger upstream time than any of its errors, and request_time (the
#    second-last field) is always a little above the upstream time;
#  - user agents contain spaces, a few TLS-on-plain-HTTP lines are malformed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p var/log/nginx etc/nginx .lm-state

cat > etc/nginx/nginx.conf <<'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format timed '$remote_addr - $remote_user [$time_local] "$request" '
                     '$status $body_bytes_sent "$http_referer" '
                     '"$http_user_agent" $request_time $upstream_response_time';
    access_log /var/log/nginx/access.log timed;
    error_log /var/log/nginx/error.log warn;

    limit_req_zone $binary_remote_addr zone=api:10m rate=20r/s;

    upstream shop_api {
        server 127.0.0.1:8080;
    }

    server {
        listen 80;
        server_name shop.example.com;
        location /static/ { root /srv/shop; expires 7d; }
        location /api/ {
            limit_req zone=api burst=40 nodelay;
            proxy_pass http://shop_api;
            proxy_read_timeout 30s;
        }
        location = /healthz { proxy_pass http://shop_api; }
    }
}
EOF

python3 - "$RANDOM$$" <<'PY'
import random, sys
rnd = random.Random(sys.argv[1])
T0, DEPLOY, T1 = 13 * 3600 + 30 * 60, 14 * 3600, 15 * 3600 + 10 * 60
UAS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0",
    "ShopApp/4.12.1 (Android 14; Pixel 8) okhttp/4.12.0",
]
REFS = ["https://shop.example.com/", "https://shop.example.com/account", "https://shop.example.com/cart", "-"]
lines = []

def ip():
    return f"{rnd.choice([81, 89, 93, 145, 178, 188, 212, 217])}.{rnd.randint(0, 255)}.{rnd.randint(0, 255)}.{rnd.randint(1, 254)}"

def add(t, method, url, status, up, ua=None, size=None):
    if up == "-":
        rt = f"{rnd.uniform(0, 0.002):.3f}"
    else:
        rt = f"{float(up) + rnd.uniform(0.001, 0.009):.3f}"
    size = size if size is not None else (rnd.randint(150, 600) if status >= 400 else rnd.randint(300, 48000))
    lines.append((t, f'{ip()} - - [10/Nov/2026:{int(t) // 3600:02d}:{int(t) // 60 % 60:02d}:{int(t) % 60:02d} +0100] '
                     f'"{method} {url} HTTP/1.1" {status} {size} "{rnd.choice(REFS)}" "{ua or rnd.choice(UAS)}" {rt} {up}'))

def up_ok():
    return f"{rnd.uniform(0.004, 0.35):.3f}"

X = rnd.choice(["/api/v2/orders", "/api/v2/search"])
def xurl():
    return f"{X}?id={rnd.randint(880000, 899999)}" if X.endswith("orders") else f"{X}?q={rnd.choice(['boots', 'rain+jacket', 'socks', 'gift+card', 'tent', 'usb-c+cable', 'mug'])}&page={rnd.randint(1, 9)}"
others = {
    "/api/v2/orders": lambda: f"/api/v2/orders?id={rnd.randint(880000, 899999)}",
    "/api/v2/search": lambda: f"/api/v2/search?q={rnd.choice(['boots', 'hat', 'lamp'])}&page=1",
    "/api/v2/cart": lambda: "/api/v2/cart",
    "/api/v2/checkout": lambda: "/api/v2/checkout",
    "/api/v2/products": lambda: f"/api/v2/products?category={rnd.choice(['shoes', 'outdoor', 'kitchen', 'kids'])}",
}

# Normal traffic, 13:30-15:10.
t = T0
while t < T1:
    r = rnd.random()
    if r < 0.25:
        add(t, "GET", f"/static/{rnd.choice(['app.3f9c1e.js', 'app.3f9c1e.css', 'logo.svg', 'hero.webp'])}", rnd.choice([200, 200, 304]), "-")
    elif r < 0.32:
        add(t, "GET", "/healthz", 200, f"{rnd.uniform(0.001, 0.004):.3f}", ua="kube-probe/1.30", size=2)
    else:
        path = rnd.choice(list(others))
        method = "POST" if path in ("/api/v2/cart", "/api/v2/checkout") else "GET"
        add(t, method, others[path](), rnd.choice([200] * 12 + [201, 204, 404]), up_ok())
    t += rnd.uniform(0.2, 1.4)

# The winner since the deploy: 5xx spread over query strings.
c1 = rnd.randint(40, 65)
n504 = rnd.randint(3, 7)
n503 = rnd.randint(4, 9)
for i in range(c1):
    tt = rnd.uniform(DEPLOY + 30, T1 - 30)
    if i < n504:
        add(tt, "GET", xurl(), 504, f"{30 + rnd.uniform(0.0005, 0.0099):.3f}", size=167)
    elif i < n504 + n503:
        add(tt, "GET", xurl(), 503, "-", size=197)
    else:
        add(tt, "GET", xurl(), rnd.choice([500, 502, 502]), f"{rnd.uniform(0.001, 2.5):.3f}", size=rnd.randint(150, 600))
# A slow but successful export on the winner, slower than any of its errors.
add(rnd.uniform(DEPLOY + 60, T1 - 60), "GET", xurl() + "&export=csv", 200, f"{rnd.uniform(41, 55):.3f}", size=rnd.randint(900000, 3000000))
# Before the deploy the winner already had a few errors, one very slow.
for _ in range(rnd.randint(3, 6)):
    add(rnd.uniform(T0, DEPLOY - 60), "GET", xurl(), 502, f"{rnd.uniform(0.01, 1):.3f}")
add(rnd.uniform(T0, DEPLOY - 60), "GET", xurl(), 504, f"{rnd.uniform(58, 59.9):.3f}", size=167)
# Checkout: fewer errors since 14:00, but all on one URL.
for _ in range(c1 - rnd.randint(6, 14)):
    add(rnd.uniform(DEPLOY + 30, T1 - 30), "POST", "/api/v2/checkout", rnd.choice([500, 502]), f"{rnd.uniform(0.05, 3):.3f}")
# Cart: a 5xx storm at 13:4x, before the deploy.
for _ in range(c1 + rnd.randint(15, 30)):
    add(rnd.uniform(13 * 3600 + 40 * 60, 13 * 3600 + 55 * 60), "POST", "/api/v2/cart", 502, f"{rnd.uniform(0.001, 0.02):.3f}")
# A few 5xx elsewhere since the deploy.
for _ in range(rnd.randint(3, 9)):
    add(rnd.uniform(DEPLOY + 30, T1 - 30), "GET", others["/api/v2/products"](), 500, f"{rnd.uniform(0.05, 1):.3f}")
# Scanners speaking TLS to port 80, and a request right before 14:00.
for _ in range(rnd.randint(3, 6)):
    tt = rnd.uniform(T0, T1)
    lines.append((tt, f'{ip()} - - [10/Nov/2026:{int(tt) // 3600:02d}:{int(tt) // 60 % 60:02d}:{int(tt) % 60:02d} +0100] "\\x16\\x03\\x01\\x00\\xEE\\x01\\x00\\x00\\xEA\\x03\\x03" 400 157 "-" "-" 0.031 -'))
add(DEPLOY - 1, "GET", xurl(), 502, f"{rnd.uniform(0.01, 0.5):.3f}")

lines.sort(key=lambda x: x[0])
with open("var/log/nginx/access.log", "w") as fh:
    for _, l in lines:
        fh.write(l + "\n")
PY
cksum var/log/nginx/access.log > .lm-state/access.sum
