#!/bin/bash
# Keep remote away from the loop's stdin, strip the CR, and handle a last
# line without a newline.
cat > check_hosts.sh <<'SCRIPT'
#!/bin/bash
# check_hosts.sh INVENTORY - run `uptime` on every host, results in status.txt
: > status.txt
while read -r host || [ -n "$host" ]; do
  host=${host%$'\r'}
  case $host in
    '#'*|'') continue ;;
  esac
  if out=$(./tools/remote "$host" uptime < /dev/null); then
    echo "$host: $out" >> status.txt
  else
    echo "$host: UNREACHABLE" >> status.txt
  fi
done < "$1"
echo "checked $(wc -l < status.txt) host(s), see status.txt"
SCRIPT
./check_hosts.sh inventory.txt
cat -A status.txt
