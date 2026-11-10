#!/bin/bash
# The Invisible Key: app.conf was pasted from a chat window on a Windows laptop.
# Every line ends in CRLF, two lines have trailing blanks, and the space before
# the "=" of the port line is a U+00A0 non-breaking space (shown as M-BM- by cat -A).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

cat > .lm-state/expected.conf <<'CONF'
# app.conf - settings for the report service
name = reports
bind = 0.0.0.0
port = 8080
workers = 4
log_level = info

# storage
data_dir = /var/lib/reports
cache_ttl = 300
timeout = 30
CONF

awk '
  /^port =/        { sub(/ =/, "\302\240=") }
  /^workers =/     { $0 = $0 "  " }
  /^# storage$/    { $0 = $0 " " }
  /^cache_ttl =/   { $0 = $0 "\t" }
  { printf "%s\r\n", $0 }
' .lm-state/expected.conf > app.conf
