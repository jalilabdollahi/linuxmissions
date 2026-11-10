#!/bin/bash
cat > inspect.sh <<'SCRIPT'
#!/bin/bash
. /etc/os-release
mem=$(awk '/^MemTotal:/ {print int($2 / 1024)}' /proc/meminfo)
up=$(awk '{print int($1)}' /proc/uptime)
root=$(df -P / | awk 'NR == 2 {sub("%", "", $5); print $5}')
ports=$(ss -ltnH | awk '{n = split($4, a, ":"); print a[n]}' | sort -un | jq -Rnc '[inputs | tonumber]')
jq -n --arg hostname "$(uname -n)" --arg kernel "$(uname -r)" --arg arch "$(uname -m)" \
  --arg os_id "$ID" --arg os_version "$VERSION_ID" \
  --argjson cpus "$(nproc)" --argjson mem "$mem" --argjson root "$root" --argjson up "$up" --argjson ports "$ports" \
  '{hostname: $hostname, kernel: $kernel, arch: $arch, os_id: $os_id, os_version: $os_version,
    cpus: $cpus, mem_total_mib: $mem, root_use_pct: $root, uptime_seconds: $up, listening_ports: $ports}'
SCRIPT
chmod +x inspect.sh
./inspect.sh
