#!/bin/bash
# One jq program, written to a temp file first: jq must read flags.json before the
# shell replaces it, and a redirection onto the input would truncate it.
jq '.flags.new_checkout.regions.eu = true | .testers += ["beta-12"] | del(.flags.xmas_banner)' flags.json > flags.json.tmp \
  && mv flags.json.tmp flags.json
jq -c '.flags | keys' flags.json
