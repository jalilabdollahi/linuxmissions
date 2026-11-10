#!/bin/bash
subj=$(sed -n 's/^ *Subject: *//p' TICKET.txt)
exec 3<>/dev/tcp/127.0.0.1/$(cat smtp.port)
read -r reply <&3; echo "$reply"
say() { printf '%s\r\n' "$1" >&3; read -r reply <&3; echo "$reply"; }
say "HELO app-07.corp.example"
say "MAIL FROM:<healthcheck@app-07.corp.example>"
say "RCPT TO:<ops@corp.example>"
say "DATA"
printf 'Subject: %s\r\nFrom: healthcheck@app-07.corp.example\r\nTo: ops@corp.example\r\n\r\nTest from app-07.\r\n.\r\n' "$subj" >&3
read -r reply <&3; echo "$reply"
say "QUIT"
exec 3<&-
