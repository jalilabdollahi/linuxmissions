#!/bin/bash
# Drop comments and blank lines, then hand each whole line to xargs as one name.
grep -Ev '^[[:space:]]*(#|$)' tenants.txt | xargs -d '\n' -t -I{} mkdir -p "tenants/{}"
grep -Ev '^[[:space:]]*(#|$)' tenants.txt | xargs -d '\n' -I{} cp template/app.conf "tenants/{}/app.conf"
ls tenants
