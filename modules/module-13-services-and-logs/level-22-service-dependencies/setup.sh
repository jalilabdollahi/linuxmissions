#!/bin/bash
# Boot order: app.service needs db-proxy, but with no ordering systemd starts
# unordered units alphabetically (= "in parallel"): app first, db-proxy
# second, so app's start-up check ("is db-proxy active?") fails. Left in the
# units to trip the player:
#   - app only has Wants=db-proxy.service (soft, and no After=);
#   - db-proxy.service has a stray After=app.service: adding the correct
#     After=db-proxy.service to app creates an ordering cycle.
# cache.service is unrelated and must keep working. The names of the checks
# are fixed; the unit descriptions are random cosmetic. Mock systemctl in bin/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin .lm .lm-state etc/systemd/system/multi-user.target.wants opt/app/bin opt/db-proxy/bin opt/cache/bin var/log/journal
cp "$M/systemd/systemctl" "$M/systemd/journalctl" "$M/systemd/systemd-analyze" bin/
echo web-07 > etc/hostname
echo "2026-11-10 06:00:00" > .lm/now

cat > opt/db-proxy/bin/db-proxy <<'LMEND2'
#!/bin/bash
# db-proxy (stand-in): connection pooler in front of the database.
echo "db-proxy: pool ready, listening on 127.0.0.1:6432"
while :; do sleep 5; done
LMEND2
cat > opt/app/bin/app <<'LMEND2'
#!/bin/bash
# app (stand-in): refuses to start unless the database proxy is up already.
ROOT="${0%/opt/app/bin/app}"
up=0
while read -r line; do [ "$line" = ActiveState=active ] && up=1; done < "$ROOT/.lm/systemd/units/db-proxy.service.state" 2>/dev/null
if [ "$up" = 0 ]; then
  echo "app: cannot connect to db-proxy at 127.0.0.1:6432: connection refused" >&2
  exit 1
fi
echo "app: connected to db-proxy, serving"
while :; do sleep 5; done
LMEND2
cat > opt/cache/bin/cache <<'LMEND2'
#!/bin/bash
echo "cache: warm, serving"
while :; do sleep 5; done
LMEND2
chmod +x opt/*/bin/*

cat > etc/systemd/system/db-proxy.service <<'LMEND2'
[Unit]
Description=Database connection pooler
After=network.target app.service

[Service]
Type=simple
ExecStart=/opt/db-proxy/bin/db-proxy
Restart=on-failure

[Install]
WantedBy=multi-user.target
LMEND2
cat > etc/systemd/system/app.service <<'LMEND2'
[Unit]
Description=Web application
After=network.target
Wants=db-proxy.service

[Service]
Type=simple
ExecStart=/opt/app/bin/app

[Install]
WantedBy=multi-user.target
LMEND2
cat > etc/systemd/system/cache.service <<'LMEND2'
[Unit]
Description=Local cache
After=network.target

[Service]
Type=simple
ExecStart=/opt/cache/bin/cache

[Install]
WantedBy=multi-user.target
LMEND2
for u in app db-proxy cache; do
  ln -s /etc/systemd/system/$u.service etc/systemd/system/multi-user.target.wants/$u.service
done
sha256sum opt/*/bin/* > .lm-state/sha

cat > TICKET.md <<'LMEND2'
# OPS-3340: web-07 comes up broken after every reboot

After a reboot app.service fails ("cannot connect to db-proxy"), and someone
has to start it by hand. Requirements:

1. At boot, db-proxy must be started BEFORE app.
2. app cannot work without db-proxy: when db-proxy is stopped, app must stop
   with it. (The other way round, stopping app must leave db-proxy running.)
3. systemd must not report any ordering cycle.
4. Keep cache.service, the three programs under /opt, and the boot targets as they are.

You can simulate a boot with `systemctl mock-boot` (mock-only command: it
stops everything and starts the default target, printing what systemd would).
LMEND2
bin/systemctl daemon-reload
