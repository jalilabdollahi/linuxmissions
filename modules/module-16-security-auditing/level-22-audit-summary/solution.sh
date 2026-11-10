#!/bin/bash
export PATH="$PWD/bin:$PATH"
{
  find host -type f -perm -0002 -printf 'world-writable\t%p\t%m\n'
  find host -type f -perm /6000 -printf '%p\t%m\n' | awk -F'\t' 'NR == FNR { b[$0] = 1; next } !($1 in b) { printf "unexpected-suid\t%s\t%s\n", $1, $2 }' host/etc/suid-baseline.txt -
  grep -rlE -- '-----BEGIN [A-Z ]*PRIVATE KEY' host | while read -r f; do m=$(stat -c %a "$f"); [ "$m" != 600 ] && printf 'weak-key-mode\t%s\t%s\n' "$f" "$m"; done
  sshd -T -f host/etc/ssh/sshd_config | awk '($1 == "permitrootlogin" || $1 == "passwordauthentication" || $1 == "x11forwarding") && $2 != "no" || $1 == "maxauthtries" && $2 > 4 { printf "sshd-setting\thost/etc/ssh/sshd_config\t%s=%s\n", $1, $2 }'
  grep -rniE '^[[:space:]]*(password|api_key|secret)[[:space:]]*=[[:space:]]*[^<$[:space:]]' host/etc host/home | awk -F: '{ printf "plaintext-secret\t%s\tline=%s\n", $1, $2 }'
} | sort -u > audit.tsv
cat audit.tsv
