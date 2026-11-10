#!/bin/bash
# Execs each helper the way cron's execve does (python3 subprocess with a list
# argv: no shell, so no "run it as a shell script" fallback) on fresh copies,
# with data the player has not seen, and compares stdout. stderr must be empty.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

for h in disk_report queue_stats backup_age; do
  f="bin/$h"
  if [ ! -f "$f" ]; then
    echo "❌ bin/$h is missing (type reset to get it back)"
    exit 1
  fi
  if [ "$(head -c 2 "$f")" != '#!' ]; then
    echo "❌ bin/$h does not start with #! (the shebang must be the very first two bytes of the file)"
    exit 1
  fi
  if [ ! -x "$f" ]; then
    echo "❌ bin/$h is not executable any more"
    exit 1
  fi
done

# On macOS /bin/sh is bash and accepts [[ ]]; on Ubuntu it is dash and does not.
first="$(head -n 1 bin/disk_report)"
case "$first" in
  '#!/bin/sh'*|'#!/usr/bin/sh'*|'#!/bin/dash'*|'#!/usr/bin/env sh'*|'#!/usr/bin/env dash'*)
    if grep -q '\[\[' bin/disk_report; then
      echo "❌ bin/disk_report still uses [[ ]] under '$first'; /bin/sh is dash on Ubuntu and has no [[ ]]"
      exit 1
    fi ;;
esac

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/bin" "$WORK/data"
cp -p bin/disk_report bin/queue_stats bin/backup_age "$WORK/bin/"

cat > "$WORK/data/df.txt" <<'EOF'
Filesystem         1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p2       102400000  71680000  30720000      70% /
/dev/nvme0n1p1         1048576    891289    157287      85% /boot
/dev/mapper/vg-var    51200000  51150000     50000     100% /var
tmpfs                  8000000   6400000   1600000      80% /run
/dev/sdb1            976762584 878985600  97776984      90% /srv/media store
/dev/sdc1             20971520   1677721  19293799       8% /home
EOF
printf '%s\n' 'FULL /boot 85%' 'FULL /var 100%' 'FULL /run 80%' 'FULL /srv/media store 90%' > "$WORK/disk.want"

printf '%s\n' '17 retry' '18 done' '19 done' '20 retry' '21 failed' '22 done' '23 done' > "$WORK/data/queue.txt"
echo 'done=4 failed=1 retry=2' > "$WORK/queue.want"

printf '%s\n' '2026-10-30 1201 db-2026-10-30.sql.gz' '2026-11-02 1190 db-2026-11-02.sql.gz' \
  '2026-10-31 1199 db-2026-10-31.sql.gz' '2026-11-01 1210 db-2026-11-01.sql.gz' > "$WORK/data/backups.txt"
echo 'newest=2026-11-02 file=db-2026-11-02.sql.gz count=4 total_mb=4800' > "$WORK/backup.want"

python3 - "$WORK" <<'PY'
import subprocess, sys
work = sys.argv[1]
cases = [("disk_report", "df.txt", "disk.want"),
         ("queue_stats", "queue.txt", "queue.want"),
         ("backup_age", "backups.txt", "backup.want")]
for helper, data, want in cases:
    path = f"{work}/bin/{helper}"
    try:
        r = subprocess.run([path, f"{work}/data/{data}"], cwd=work, capture_output=True,
                           text=True, timeout=10, stdin=subprocess.DEVNULL)
    except FileNotFoundError:
        interp = open(path, "rb").readline().decode(errors="replace").strip()
        print(f"❌ bin/{helper}: the kernel cannot find the interpreter named in its first line ({interp})")
        sys.exit(1)
    except OSError as exc:
        print(f"❌ bin/{helper} cannot be executed directly: {exc.strerror} (look at its first line)")
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(f"❌ bin/{helper} did not finish within 10 seconds")
        sys.exit(1)
    if r.stderr.strip():
        print(f"❌ ./bin/{helper} printed an error: {r.stderr.strip().splitlines()[0]}")
        sys.exit(1)
    expected = open(f"{work}/{want}").read()
    if r.stdout != expected:
        got = r.stdout.strip().splitlines()
        print(f"❌ ./bin/{helper} on other data printed {got[:2] if got else 'nothing'}, "
              f"expected {expected.strip().splitlines()[:2]}")
        sys.exit(1)
PY
[ $? -eq 0 ] || exit 1

echo "✅ all three helpers run as ./bin/<name>, exactly the way cron starts them"
exit 0
