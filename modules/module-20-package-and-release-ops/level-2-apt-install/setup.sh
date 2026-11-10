#!/bin/bash
# Exactly 3.1.4: fluxd is not installed, the mirror has three
# releases, each needing a different libflux1 range. Installed: libflux1 1.5.0
# (too new for the ticket's version, and apt will not downgrade it by itself).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p "$SANDBOX/.lm"
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim

target, need = "3.1.4-1", "1.4.2-1"
def lib(v):
    return {"name": "libflux1", "version": v, "description": "flux runtime library",
            "files": {"/usr/lib/libflux.so.1": f"libflux {v}\n"}}
def fluxd(v, dep):
    return {"name": "fluxd", "version": v, "depends": dep, "description": "flux daemon",
            "files": {"/usr/sbin/fluxd": {"content": f"#!/bin/sh\necho fluxd {v}\n", "mode": "0755"},
                      "/etc/fluxd/fluxd.conf": "listen = 127.0.0.1:7700\n"}}
fx = {"repos": [{"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "packages": [
        fluxd("3.2.0-1", "libflux1 (>= 1.5)"),
        fluxd("3.1.4-1", "libflux1 (>= 1.4), libflux1 (<< 1.5)"),
        fluxd("3.0.9-1", "libflux1 (<< 1.4)"),
        lib("1.5.0-1"), lib("1.4.2-1"), lib("1.3.7-1"),
        {"name": "fluxctl", "version": "2.0-1", "description": "flux admin client", "depends": "libflux1"},
        {"name": "fluxctl", "version": "2.1-1", "description": "flux admin client", "depends": "libflux1"},
        {"name": "curl", "version": "8.5.0-1", "description": "transfer tool"},
        {"name": "curl", "version": "8.5.0-2", "description": "transfer tool"},
      ]}],
      "installed": [{"name": "libflux1", "version": "1.5.0-1"}, {"name": "fluxctl", "version": "2.0-1"},
                    {"name": "curl", "version": "8.5.0-1"}]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
open(sandbox + "/TICKET.txt", "w").write(
    f"OPS-2291  fluxd 3.2.0 breaks the billing plugin (it crashes on start).\n"
    f"Run fluxd {target.rsplit('-', 1)[0]} (package version {target}) until the plugin vendor ships a fix.\n"
    f"Do not touch anything else on this server.\n")
open(sandbox + "/.lm/target", "w").write(target + " " + need + "\n")
PY
/usr/bin/dpkg-query --root="$SANDBOX/rootfs" -W -f='${Package} ${Version}\n' | grep -v '^base-files ' | sort > "$SANDBOX/.lm/baseline"
