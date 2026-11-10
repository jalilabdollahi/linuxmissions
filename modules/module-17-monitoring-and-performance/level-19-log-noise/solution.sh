#!/bin/bash
sed -E 's/^[^ ]+ [^ ]+ //; s/[0-9a-f]{8}/ID/g; s/[0-9]+/N/g' app.log | sort | uniq -c | sort -rn | head -5
cat > drop.patterns <<'LMEND'
 INFO cache hit key=
 DEBUG http GET /v1/errors/report\?session=[0-9a-f]+ status=200
 INFO healthcheck probe from [0-9.]+ ok in
LMEND
grep -vEf drop.patterns app.log | wc -l
