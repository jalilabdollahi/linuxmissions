#!/bin/bash
./app --check
n=$(grep -o 'to [0-9]*' TICKET.md | head -1 | cut -d' ' -f2)
jq --argjson n "$n" '.db.pool_size = $n | .features.audit_log = true' config.json.last-good > config.json.new
mv config.json.new config.json
./app --check
