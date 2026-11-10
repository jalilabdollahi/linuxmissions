#!/bin/bash
# rotate.sh has a working body but no option parsing yet. The validator runs
# it with clustered options, attached values, -- and bad usage.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > rotate.sh <<'EOF'
#!/bin/bash
# rotate.sh [-v] [-n COUNT] -d DIR [PATTERN...]
#   -d DIR     directory to clean up (required)
#   -n COUNT   how many of the newest files to keep per pattern (default 7)
#   -v         report every removed file on stderr
#   PATTERN    glob(s) inside DIR, default '*.log'. Put -- before a pattern
#              that starts with a dash.
# Options may come in any order and be clustered (-vn3) or attached (-dlogs).
# Wrong usage (unknown option, option without its value, no -d):
# the usage line on stderr and exit 2, before anything else happens.

count=7
dir=
verbose=0

usage() {
  echo "usage: rotate.sh [-v] [-n COUNT] -d DIR [PATTERN...]" >&2
  exit 2
}

# TODO: parse the options here, then remove them from the arguments so
# that "$@" holds only the patterns.

# ---- everything below already works: do not change it ----
case $count in ''|*[!0-9]*) usage ;; esac
[ "$#" -eq 0 ] && set -- '*.log'
echo "rotate: dir=$dir keep=$count verbose=$verbose patterns=$(printf '[%s]' "$@")"
if [ ! -d "$dir" ]; then
  echo "rotate: no such directory: $dir" >&2
  exit 1
fi
for pattern in "$@"; do
  IFS=     # no word splitting here: a pattern with a space stays one pattern
  matches=()
  for f in "$dir"/$pattern; do
    [ -f "$f" ] && matches+=("$f")
  done
  unset IFS
  [ "${#matches[@]}" -gt 0 ] || continue
  ls -1t -- "${matches[@]}" | tail -n +$((count + 1)) | while IFS= read -r old; do
    rm -f -- "$old"
    if [ "$verbose" = 1 ]; then echo "rotate: removed $old" >&2; fi
  done
done
exit 0
EOF
chmod +x rotate.sh

mkdir -p logs
for d in 01 02 03 04 05 06 07 08 09 10; do
  echo "api log for 2026-11-$d" > "logs/api-2026-11-$d.log"
  touch -t "202611${d}2359" "logs/api-2026-11-$d.log"
done
echo "keep me" > logs/README

cat > crontab.txt <<'EOF'
# what ops wants to run once rotate.sh understands options
15 4 * * *  /srv/ops/rotate.sh -d /var/log/api -n 14
20 4 * * *  /srv/ops/rotate.sh -vn3 -d /var/log/worker 'worker-*.log' 'gc *.log'
EOF
