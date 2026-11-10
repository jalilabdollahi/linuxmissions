#!/bin/bash
# Authorised GET of /health, then pull .service.status out of the JSON.
curl -s -H "X-API-Key: $(cat api.key)" "$(cat api_url.txt)/health" | jq -r '.service.status' > status.txt
cat status.txt
