#!/bin/bash
# Just the Nginx Config: a full /etc backup made with `tar -czf ... -C / .`-style
# names (./etc/...). The player extracts only ./etc/nginx into restore/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

B=.build
E=$B/etc
mkdir -p "$E"

# The nginx tree the player has to get back.
mkdir -p "$E/nginx/sites-available" "$E/nginx/sites-enabled" "$E/nginx/conf.d" "$E/nginx/snippets"
cat > "$E/nginx/nginx.conf" <<'CONF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events { worker_connections 1024; }

http {
    sendfile on;
    server_tokens off;
    include /etc/nginx/mime.types;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
CONF
printf 'types {\n    text/html html htm;\n    text/css css;\n    application/javascript js;\n    image/svg+xml svg;\n}\n' > "$E/nginx/mime.types"
printf 'gzip on;\ngzip_types text/css application/javascript image/svg+xml;\n' > "$E/nginx/conf.d/gzip.conf"
printf 'limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;\n' > "$E/nginx/conf.d/ratelimit.conf"
printf 'ssl_protocols TLSv1.2 TLSv1.3;\nssl_session_cache shared:SSL:10m;\n' > "$E/nginx/snippets/tls.conf"
for site in shop api status; do
  cat > "$E/nginx/sites-available/$site.conf" <<CONF
server {
    listen 443 ssl;
    server_name $site.web-04.example;
    include snippets/tls.conf;
    root /srv/$site;
    access_log /var/log/nginx/$site.access.log;
}
CONF
done
ln -s ../sites-available/shop.conf "$E/nginx/sites-enabled/shop.conf"
ln -s ../sites-available/api.conf "$E/nginx/sites-enabled/api.conf"

# Things that look like nginx but live elsewhere in /etc.
mkdir -p "$E/logrotate.d" "$E/default" "$E/ufw/applications.d"
printf '/var/log/nginx/*.log {\n    daily\n    rotate 14\n    compress\n}\n' > "$E/logrotate.d/nginx"
printf '# Options for nginx\nDAEMON_OPTS=""\n' > "$E/default/nginx"
printf '[Nginx Full]\ntitle=Web Server (Nginx, HTTP + HTTPS)\nports=80,443/tcp\n' > "$E/ufw/applications.d/nginx"

# Lots of ordinary /etc noise, so that unpacking everything is not an option.
for pkg in apt ssh systemd cron sudoers.d security pam.d profile.d X11 fonts ssl python3 udev; do
  mkdir -p "$E/$pkg"
  for i in $(seq 1 150); do
    printf '# %s config fragment %d\nkey_%d = %d\n' "$pkg" "$i" "$i" $(( (i * 7919) % 1000 )) > "$E/$pkg/part-$i.conf"
  done
done
printf 'web-04\n' > "$E/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 web-04\n' > "$E/hosts"

tar -czf etc-backup.tar.gz -C "$B" .
rm -rf "$B"
mkdir -p restore
