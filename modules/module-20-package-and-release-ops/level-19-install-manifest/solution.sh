#!/bin/bash
export LC_ALL=C
manifest() {
  (cd "$1" && find . -type f -printf '%P\n' | sort | while IFS= read -r p; do
    printf '%s %s %s\n' "$(stat -c %a "$p")" "$(sha256sum < "$p" | cut -d' ' -f1)" "$p"
  done)
}
manifest release > MANIFEST
manifest deployed > deployed.manifest
awk 'NR == FNR { k = $0; sub(/^[^ ]+ [^ ]+ /, "", k); m[k] = $1 " " $2; next }
     { k = $0; sub(/^[^ ]+ [^ ]+ /, "", k); d[k] = $1 " " $2
       if (!(k in m)) print "EXTRA " k; else if (m[k] != d[k]) print "MODIFIED " k }
     END { for (k in m) if (!(k in d)) print "MISSING " k }' MANIFEST deployed.manifest | sort > deploy-diff.txt
