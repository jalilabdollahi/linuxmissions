#!/bin/bash
# 1. take only the blob out of the cron line (the word after "echo")
blob=$(grep 'base64 -d | sh' suspicious.cron | sed 's/.* echo \([^ ]*\) |.*/\1/')
# 2. layer 1 is base64url without padding: back to the normal alphabet, then re-add the = padding
std=$(printf '%s' "$blob" | tr '_-' '/+')
while [ $((${#std} % 4)) -ne 0 ]; do std="$std="; done
# 3. decode it: that gives gzip data; gunzip gives text which is base64 again (layer 3)
printf '%s' "$std" | base64 -d | gunzip > stage2.b64
base64 -d stage2.b64 > payload.txt
cat payload.txt
# 4. read the two facts from the payload text; nothing was executed
host=$(grep -o 'https://[^/]*' payload.txt | cut -d/ -f3)
drop=$(grep -o 'writing .*"' payload.txt | sed 's/^writing //; s/"$//')
printf 'c2=%s\ndropped=%s\n' "$host" "$drop" > ioc.txt
