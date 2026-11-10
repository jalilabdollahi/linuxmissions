#!/bin/bash
cd triage
# first login from a source that is neither office nor VPN
line=$(grep Accepted var/log/auth.log | grep -vE ' from (10\.0\.5\.|192\.0\.2\.50 )' | head -1)
ip=$(sed -n 's/.* from \([0-9.]*\) port.*/\1/p' <<<"$line")
mon=$(awk '{print $1}' <<<"$line"); day=$(awk '{print $2}' <<<"$line"); tm=$(awk '{print $3}' <<<"$line")
tu=$(date -u -d "$mon $day 2026 $tm +0330" +%Y-%m-%dT%H:%M:%SZ)
s=$(date -u -d "$tu" +%s)
# files whose ctime is inside the incident but whose mtime is old, and that no package owns
bin=$(awk -F'\t' -v s="$s" '$3>=s && $2<s-86400 {print $1}' stat.tsv | while read -r p; do grep -rqxF "$p" var/lib/dpkg/info || echo "$p"; done | head -1)
pers=$(awk -F'\t' -v s="$s" '$3>=s && $1 ~ /(cron\.d|systemd\/system|authorized_keys)/ && $1 !~ /\.wants\// {print $1}' stat.tsv | sort)
host=$(grep -a -o 'cfg=[A-Za-z0-9+/=]*' ".$bin" | cut -d= -f2- | base64 -d | sed 's/^c2=\([^:;]*\).*/\1/')
cd ..
jq -n --arg t "$tu" --arg ip "$ip" --arg b "$bin" --arg h "$host" --arg p "$pers" \
  '{first_malicious_login:{time_utc:$t, ip:$ip}, persistence:($p|split("\n")), exfil_host:$h, dropped_binary:$b}' > incident.json
