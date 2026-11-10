# Speaking SMTP by Hand

## Why it works
In bash, `/dev/tcp/HOST/PORT` is not a real file: bash itself opens a TCP
connection when you redirect to it. `exec 3<>` keeps that connection open on
descriptor 3, so `printf ... >&3` sends and `read <&3` receives, one exchange
at a time. SMTP is a line protocol where the server answers every command
with a three-digit code, and this relay (like Postfix with
`smtpd_data_restrictions = reject_unauth_pipelining`) hangs up on clients that
talk before it has answered: reading each reply before the next command is not
politeness, it is the protocol. The message itself ends with CRLF, a dot, CRLF;
a bare `\n` is rejected because it is how spam bots and broken scripts give
themselves away.

## Common mistakes
- `echo "HELO x" >&3`: sends LF only. Use `printf '...\r\n'`.
- Sending several commands in one printf: the relay hasn't answered the first one yet.
- Putting the Subject on the `DATA` line or in MAIL FROM: headers go inside the message data.
- `EHLO` answers with several `250-` lines; read them all (until a line starts with `250 `) or your replies get out of step.

## Learn next
`timeout 2 bash -c '</dev/tcp/HOST/PORT'` is a port check with nothing
installed. For TLS on port 587/465, bash can't help:
`openssl s_client -starttls smtp -connect HOST:587 -crlf` gives you the same
conversation over an encrypted channel.
