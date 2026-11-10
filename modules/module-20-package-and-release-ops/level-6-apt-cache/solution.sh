#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
apt-cache policy nginx
cand=$(apt-cache policy nginx | awk '/Candidate:/ {print $2}')
prio=$(apt-cache policy nginx | awk -v v="$cand" '{sub(/^[ *]+/, "")} $1 == v {print $2}')
url=$(apt-cache policy nginx | awk -v v="$cand" '{sub(/^[ *]+/, "")} $1 == v {f=1; next} f && $2 ~ /^file:/ {print $2; exit}')
origin=$(apt-cache policy | grep -A1 -F "$url " | grep -o 'o=[^,]*' | head -1 | cut -c3-)
file=$(grep -l "Pin-Priority: $prio" rootfs/etc/apt/preferences.d/*.pref | head -1)
printf 'CANDIDATE=%s\nORIGIN=%s\nPREF_FILE=%s\n' "$cand" "$origin" "$file" > why.env
cat why.env
