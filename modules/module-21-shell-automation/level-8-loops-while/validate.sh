#!/bin/bash
# Runs check_hosts.sh with a validator-owned remote mock that, like ssh,
# drains stdin unless -n is given, on the shipped inventory and on a hidden
# one (CRLF lines, a CRLF blank line, comments, an unreachable host, no final
# newline). Compares the call log (hosts, in order) and status.txt exactly.
SANDBOX="$1"
SCRIPT="$SANDBOX/check_hosts.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ check_hosts.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/tools"
cp "$SCRIPT" "$WORK/check_hosts.sh"
cat > "$WORK/tools/remote" <<'EOF'
#!/bin/bash
nostdin=0
if [ "$1" = -n ]; then nostdin=1; shift; fi
host=$1
printf '[%s]\n' "$host" >> calls.log
[ "$nostdin" = 1 ] || cat > /dev/null
case $host in
  lb-1|queue-01|mx-2) exit 255 ;;
esac
case $host in
  *[!a-z0-9-]*|'') exit 255 ;;
esac
echo "up ${#host} days, load 0.$(printf '%s' "$host" | cksum | cut -c1-2)"
EOF
chmod +x "$WORK/tools/remote"
cd "$WORK" || exit 1
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"

answer() { echo "up ${#1} days, load 0.$(printf '%s' "$1" | cksum | cut -c1-2)"; }

# run LABEL INVENTORY HOST... (hosts in order; lb-1, queue-01 and mx-2 are down)
run() {
  label=$1 inv=$2; shift 2
  rm -f calls.log status.txt
  : > want.calls; : > want.status
  for h in "$@"; do
    printf '[%s]\n' "$h" >> want.calls
    case $h in
      lb-1|queue-01|mx-2) echo "$h: UNREACHABLE" >> want.status ;;
      *) echo "$h: $(answer "$h")" >> want.status ;;
    esac
  done
  $LIMIT bash ./check_hosts.sh "$inv" </dev/null >/dev/null 2>&1
  touch calls.log
  if ! cmp -s calls.log want.calls; then
    n=$(wc -l < calls.log | tr -d ' ')
    if [ "$n" = $(( $# - 1 )) ] && [ "$(head -n "$n" want.calls)" = "$(cat calls.log)" ]; then
      echo "❌ $label: every host but the last one was probed; the last line has no newline at the end"
    elif [ "$n" -lt "$#" ]; then
      echo "❌ $label: remote was called for $n of the $# hosts ($(tr '\n' ' ' < calls.log | cat -v)); the loop stops early"
    else
      echo "❌ $label: remote was called with $(tr '\n' ' ' < calls.log | cat -v| cut -c1-150), expected $(tr '\n' ' ' < want.calls)"
    fi
    exit 1
  fi
  if [ ! -f status.txt ] || ! cmp -s status.txt want.status; then
    bad=$(diff want.status status.txt 2>/dev/null | grep -m1 '^>' | cut -c3- | cat -v)
    echo "❌ $label: status.txt is not right; first wrong line: '${bad:-<missing line>}' (expected e.g. '$(head -n 1 want.status)')"
    exit 1
  fi
}

printf '%s\n' '# inventory exported from CMDB 2026-11-10' '# frontend' > shipped.txt
printf '%s\r\n' 'web-01' 'web-02' '' >> shipped.txt
printf '%s\n' '# data tier' 'db-01' 'cache-01' '' >> shipped.txt
printf '%s\r\n' 'queue-01' 'backup-01' >> shipped.txt
printf '%s' 'mon-01' >> shipped.txt
run "inventory.txt" shipped.txt web-01 web-02 db-01 cache-01 queue-01 backup-01 mon-01

printf '%s\r\n' '# edge sites' 'edge-ams-1' '' '# load balancers' 'lb-1' > hidden.txt
printf '%s\n' '' '' 'edge-fra-2' '#edge-old-9' 'mx-2' >> hidden.txt
printf '%s\r\n' 'build-7' 'cdn-03' >> hidden.txt
printf '%s' 'ci-runner-1' >> hidden.txt
run "another inventory" hidden.txt edge-ams-1 lb-1 edge-fra-2 mx-2 build-7 cdn-03 ci-runner-1

echo "✅ check_hosts.sh probes every host in order, whatever the line endings, and status.txt is clean"
exit 0
