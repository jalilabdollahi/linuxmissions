#!/bin/bash
# JSON Surgeon: an inventory API response. The owner's e-mail is one entry in
# a contacts array; "active" is nested under status and missing for some
# services (planned ones have an empty status object).
SANDBOX="$1"

awk 'BEGIN {
  n = split("api worker scheduler mailer billing search cache-warmer thumbnailer auth gateway " \
            "reports exporter importer notifier webhooks metrics audit-log geoip pdf-render ledger " \
            "fraud-check recommender inventory pricing cart checkout shipping returns loyalty chat-bot", s, " ")
  print "{"
  print "  \"meta\": {"
  print "    \"generated\": \"2024-04-08T14:30:00Z\","
  print "    \"source\": \"inventory-api v3\","
  print "    \"owner\": {"
  print "      \"team\": \"Platform Ops\","
  print "      \"contacts\": ["
  print "        {\"type\": \"pager\", \"value\": \"+1-555-0100\"},"
  print "        {\"type\": \"email\", \"value\": \"platform-ops@example.com\"},"
  print "        {\"type\": \"chat\", \"value\": \"#platform-ops\"}"
  print "      ]"
  print "    }"
  print "  },"
  print "  \"services\": ["
  for (i = 1; i <= n; i++) {
    k = (i * 7) % 5
    if (k == 0)      st = "{}"
    else if (k == 2) st = "{\"active\": false, \"since\": \"2024-03-0" (i % 9 + 1) "\"}"
    else             st = "{\"active\": true, \"since\": \"2024-02-" (10 + i % 18) "\"}"
    printf "    {\"name\": \"%s\", \"port\": %d, \"status\": %s, \"tags\": [\"%s\"]}%s\n", s[i], 8000 + i * 10, st, (i % 3 ? "prod" : "internal"), (i < n ? "," : "")
  }
  print "  ]"
  print "}"
}' > "$SANDBOX/data.json"
