#!/bin/bash
# current -> releases/<newest> throws 500s. The previous release (also with
# failures) is linked as `previous`. Versions are chosen so that lexicographic
# order differs from version order (v2.3.9 < v2.3.10); the clean newest
# release has "500ms" latencies, which fool a naive grep -c 500.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p releases shared/uploads .lm-state
echo "DB_URL=sqlite:///shared/app.db" > shared/config.env
cat > appctl <<'SH'
#!/bin/bash
# appctl: tiny stand-in for the app server's control tool.
BASE=$(cd "$(dirname "$0")" && pwd)
case "$1" in
  reload)
    if ! real=$(readlink -f "$BASE/current") || [ ! -d "$real" ]; then echo "appctl: current does not point at a release" >&2; exit 1; fi
    echo "$(date +%s) reload release=$(basename "$real")" >> "$BASE/.lm-state/appctl.log"
    echo "reloaded: now serving $(basename "$real")" ;;
  status)
    real=$(readlink -f "$BASE/current")
    echo "serving: $(basename "$real")"
    tail -1 "$BASE/.lm-state/appctl.log" 2>/dev/null || echo "no reload yet" ;;
  *) echo "usage: appctl reload|status" >&2; exit 2 ;;
esac
SH
chmod 755 appctl
: > .lm-state/appctl.log
python3 - <<'PY'
import json, os, random
R = random.Random()
y = R.randint(2, 4)
base = [(y, 1, R.randint(5, 8)), (y, 3, 9), (y, 3, 10), (y, 3, 11), (y, 4, 0)]
vers = ["v%d.%d.%d" % t for t in base]
fail = {vers[0]: 0, vers[1]: 0, vers[2]: 0, vers[3]: R.randint(3, 9), vers[4]: R.randint(40, 90)}
for v in vers:
    d = "releases/" + v
    os.makedirs(d)
    open(d + "/app.bin", "w").write("build " + v + "\n")
    os.symlink("../../shared", d + "/shared")
    lines = []
    n = R.randint(120, 200)
    bad = set(R.sample(range(n), fail[v]))
    for i in range(n):
        st = R.choice([500, 502, 503]) if i in bad else 200
        lat = R.choice([500, 500, 12, 48, 95, 130]) if v == vers[2] else R.randint(8, 140)
        lines.append("2026-11-%02dT%02d:%02d:%02dZ GET /health %d %dms" % (R.randint(1, 9), R.randint(0, 23), R.randint(0, 59), R.randint(0, 59), st, lat))
    open(d + "/health.log", "w").write("\n".join(sorted(lines)) + "\n")
os.symlink("releases/" + vers[4], "current")
os.symlink("releases/" + vers[3], "previous")
json.dump({"target": vers[2], "versions": vers}, open(".lm-state/truth.json", "w"))
open("INCIDENT.md", "w").write("""# v%s throws 500s

Roll back now. `current` is what the app server serves; `shared/` holds uploads
and config, linked into every release. Each release keeps the health
checks it served in `health.log` (fields: time, method, path, status, latency).
After switching, tell the app server with `./appctl reload`.
Go back to the newest release that never failed a health check.
""" % vers[4][1:])
PY
