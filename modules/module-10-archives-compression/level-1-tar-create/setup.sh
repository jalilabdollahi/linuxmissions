#!/bin/bash
# Ship the Site: pack build/dist/site/ so that the archive unpacks into site/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

D=build/dist/site
mkdir -p "$D/about" "$D/css" "$D/js" "$D/img" "$D/.well-known" build/cache

cat > "$D/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Larchwood Bikes</title>
<link rel="stylesheet" href="/css/site.css"></head>
<body><h1>Larchwood Bikes</h1><p>Release 2.3: new spring catalogue.</p>
<script src="/js/app.js"></script></body>
</html>
HTML
cat > "$D/about/index.html" <<'HTML'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>About us</title></head>
<body><h1>About</h1><p>Family workshop since 1987.</p></body></html>
HTML
printf 'body{font-family:system-ui;margin:0 auto;max-width:60rem}\nh1{color:#2a5d34}\n' > "$D/css/site.css"
printf 'document.addEventListener("DOMContentLoaded",()=>console.log("larchwood 2.3"));\n' > "$D/js/app.js"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="30" fill="#2a5d34"/></svg>\n' > "$D/img/logo.svg"
printf 'User-agent: *\nDisallow: /cart/\n' > "$D/robots.txt"
cat > "$D/.htaccess" <<'HT'
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
ErrorDocument 404 /index.html
HT
printf 'Contact: mailto:security@larchwood.example\nExpires: 2027-06-30T00:00:00Z\n' > "$D/.well-known/security.txt"

# Build leftovers next to site/ that must not ship.
printf '<html><body>bundle analyzer report</body></html>\n' > build/dist/stats.html
printf 'cache-key 9f3c2e\n' > build/cache/webpack.lock
