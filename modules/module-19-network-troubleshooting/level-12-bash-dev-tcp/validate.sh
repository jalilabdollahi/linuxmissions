#!/bin/bash
# Reads the SMTP server's log: a message from healthcheck@app-07.corp.example
# to ops@corp.example with the ticket's subject must have been queued.
SANDBOX="$1"
LOG="$SANDBOX/.net/smtp.log"
SUBJECT=$(cat "$SANDBOX/.net/subject")
FROM="healthcheck@app-07.corp.example"

if ! grep -q 'connect from' "$LOG" 2>/dev/null; then
  echo "❌ nobody has connected to the mail relay yet"
  exit 1
fi
if grep -qF "from=<$FROM> to=<ops@corp.example> size=" "$LOG" && grep -F "from=<$FROM> to=<ops@corp.example> size=" "$LOG" | grep -qF "subject=\"$SUBJECT\""; then
  echo "✅ the relay queued the test message for ops@corp.example ($(grep -F "subject=\"$SUBJECT\"" "$LOG" | tail -n 1 | awk '{print $4}'))"
  exit 0
fi
last=$(grep ' queued ' "$LOG" | tail -n 1)
if [ -n "$last" ]; then
  if ! echo "$last" | grep -qF "from=<$FROM>"; then
    echo "❌ a message was queued, but its envelope sender (MAIL FROM) is not $FROM"
  elif ! echo "$last" | grep -qF "to=<ops@corp.example>"; then
    echo "❌ a message was queued, but not for ops@corp.example alone"
  else
    echo "❌ a message was queued, but its Subject: header is not the one in the ticket (it goes in the message data, after DATA)"
  fi
  exit 1
fi
if grep -q 'sync error\|talked before the greeting' "$LOG"; then
  echo "❌ the relay hung up: a command arrived before it had answered the previous one (read each reply first)"
elif grep -q 'bare LF' "$LOG"; then
  echo "❌ the relay hung up: a line ended in a bare LF; SMTP lines end in CRLF (\\r\\n), the final dot too"
elif grep -q 'S: 5[0-9][0-9] 5\.1\.1\|S: 454' "$LOG"; then
  echo "❌ the relay rejected a recipient; check the address in RCPT TO"
else
  echo "❌ no message has been accepted yet (DATA ends with a line holding only a dot, and the relay answers 250 ... queued as ...)"
fi
exit 1
