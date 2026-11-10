#!/bin/bash
# Remove Is Not Purge: oldmon is in state rc (removed, config files left);
# oldmon-plugins (installed) shares /etc/oldmon, and legacy-ntp is another rc
# package that must be left alone.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p "$SANDBOX/.lm"
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import random, sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim

r = random.Random()
port = r.choice([8125, 9100, 9273, 9411])
fx = {"repos": [{"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "packages": [
         {"name": "oldmon", "version": "2.7.1-3", "description": "legacy host monitor",
          "files": {"/usr/sbin/oldmon": {"content": "#!/bin/sh\n", "mode": "0755"},
                    "/etc/oldmon/oldmon.conf": f"listen_port = {port}\ncollector = metrics.internal\n",
                    "/etc/oldmon/rules.d/default.rules": "alert disk > 90\nalert load > 8\n"}},
         {"name": "oldmon-plugins", "version": "2.7.1-3", "description": "plugins for oldmon",
          "files": {"/usr/lib/oldmon/disk.so": "so\n", "/etc/oldmon/plugins.d/disk.conf": "mounts = /,/var\n"}},
         {"name": "legacy-ntp", "version": "1.2-1", "description": "old time sync daemon",
          "files": {"/usr/sbin/legacy-ntpd": {"content": "#!/bin/sh\n", "mode": "0755"},
                    "/etc/legacy-ntp/ntp.conf": "server pool.internal\n"}},
         {"name": "nginx-light", "version": "1.24.0-2", "description": "small web server",
          "files": {"/usr/sbin/nginx": {"content": "#!/bin/sh\n", "mode": "0755"}, "/etc/nginx/nginx.conf": "events {}\n"}},
         {"name": "monagent", "version": "1.0.0-1", "description": "new monitoring agent",
          "files": {"/usr/bin/monagent": {"content": "#!/bin/sh\n", "mode": "0755"}}},
      ]}],
      "installed": [{"name": "oldmon", "state": "rc"}, "oldmon-plugins", {"name": "legacy-ntp", "state": "rc"}, "nginx-light"]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
PY
/usr/bin/dpkg-query --root="$SANDBOX/rootfs" -W -f='${db:Status-Abbrev}${Package} ${Version}\n' | grep -v -e ' base-files ' -e 'oldmon ' | sort > "$SANDBOX/.lm/baseline"
