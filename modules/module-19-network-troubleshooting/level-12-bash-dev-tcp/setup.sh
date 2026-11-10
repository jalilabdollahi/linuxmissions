#!/bin/bash
# A strict Postfix-like SMTP server on loopback (no pipelining, CRLF only).
# The ticket's subject (with a random incident number) is what the validator
# looks for in the server's log.
SANDBOX="$1"
NET="$SANDBOX/.net"; mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/smtp_server.py" "$NET/"

inc="INC-$((40000 + RANDOM % 50000))"
subject="Mail path check $inc from app-07"
printf '%s\n' "$subject" > "$NET/subject"

python3 "$NET/smtp_server.py" --hostname mail.corp.example --domain corp.example \
    --mailbox ops@corp.example --mailbox noc@corp.example --mailbox postmaster@corp.example \
    --strict --log "$NET/smtp.log" --spool "$NET/spool" \
    --port-file "$SANDBOX/smtp.port" --daemon \
  || { echo "could not start the SMTP server" >&2; exit 1; }

# app-07 is a minimal image: the usual network clients are "not installed".
# The game shell has $SANDBOX/bin first on PATH, so these stubs shadow them.
mkdir -p "$SANDBOX/bin"
for tool in nc ncat netcat telnet socat curl wget swaks sendmail mail mailx openssl; do
  cat > "$SANDBOX/bin/$tool" <<STUB
#!/bin/sh
echo "bash: $tool: command not found (app-07 is a minimal image: use bash itself)" >&2
exit 127
STUB
  chmod +x "$SANDBOX/bin/$tool"
done

cat > "$SANDBOX/TICKET.txt" <<EOF
$inc  Prove that app-07 can send mail
$(printf '%*s' ${#inc} '' | tr ' ' '-')----------------------------------
app-07 is a minimal container: no mail client, no telnet, no nc, just
bash. Alerts from it never arrive, and the mail team says the relay is
fine. Prove it by delivering one test message by hand to the relay
(127.0.0.1, port in smtp.port) with exactly this envelope and subject:

  envelope sender:  healthcheck@app-07.corp.example
  recipient:        ops@corp.example
  Subject: $subject

The relay is strict: it drops clients that send a command before it has
answered the previous one, and it only accepts lines ending in CRLF.
EOF
