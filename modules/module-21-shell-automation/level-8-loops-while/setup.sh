#!/bin/bash
# check_hosts.sh loops over the inventory with `while read`, but tools/remote
# (like ssh) reads stdin and swallows the rest of the file after the first
# host. The inventory also has CRLF lines, comments, blank lines and no
# newline at the end.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p tools

cat > tools/remote <<'EOF'
#!/bin/bash
# remote [-n] HOST COMMAND...   - stand-in for ssh in this lab.
# Like ssh, it passes its standard input on to the remote command, so it
# reads stdin until the end, unless -n is given (stdin from /dev/null).
nostdin=0
if [ "$1" = -n ]; then nostdin=1; shift; fi
host=$1
shift
if [ "$nostdin" = 0 ] && [ ! -t 0 ]; then cat > /dev/null; fi
case $host in
  web-01)    echo "up 41 days, load 0.22" ;;
  web-02)    echo "up 41 days, load 0.19" ;;
  db-01)     echo "up 203 days, load 1.87" ;;
  cache-01)  echo "up 9 days, load 0.05" ;;
  backup-01) echo "up 2 days, load 3.10" ;;
  mon-01)    echo "up 77 days, load 0.41" ;;
  queue-01)  echo "ssh: connect to host queue-01 port 22: Connection timed out" >&2; exit 255 ;;
  *)         echo "ssh: Could not resolve hostname $host: Name or service not known" >&2; exit 255 ;;
esac
EOF
chmod +x tools/remote

cat > check_hosts.sh <<'EOF'
#!/bin/bash
# check_hosts.sh INVENTORY - run `uptime` on every host in INVENTORY with
# ./tools/remote and write one line per host to status.txt, in inventory order:
#   <host>: <what uptime printed>     when the host answered
#   <host>: UNREACHABLE               when ./tools/remote failed
# INVENTORY has one host per line; lines starting with # and empty lines are
# skipped. It is exported from the CMDB and may have Windows line endings.

: > status.txt
while read host; do
  case $host in
    '#'*|'') continue ;;
  esac
  if out=$(./tools/remote "$host" uptime); then
    echo "$host: $out" >> status.txt
  else
    echo "$host: UNREACHABLE" >> status.txt
  fi
done < "$1"
echo "checked $(wc -l < status.txt) host(s), see status.txt"
EOF
chmod +x check_hosts.sh

# CMDB export: mixed line endings, comments, blank lines, no final newline.
printf '%s\n' '# inventory exported from CMDB 2026-11-10' '# frontend' > inventory.txt
printf '%s\r\n' 'web-01' 'web-02' '' >> inventory.txt
printf '%s\n' '# data tier' 'db-01' 'cache-01' '' >> inventory.txt
printf '%s\r\n' 'queue-01' 'backup-01' >> inventory.txt
printf '%s' 'mon-01' >> inventory.txt
