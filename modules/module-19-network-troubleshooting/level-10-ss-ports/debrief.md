# Address Already in Use

## Why it works
Only one socket can listen on an address and port, so the new release
failed with EADDRINUSE while the forgotten 1.9 instance still held it.
`ss -ltnp` lists listening TCP sockets together with the owning process;
its filter `sport = :PORT` matches the port exactly, while `grep PORT` also
matched audit-relay, whose port number merely starts with the same digits.
Checking the command line with `ps -ww -o args` before `kill` is the habit that
keeps you from stopping the wrong service: here every service showed up as
plain "python3".

## Common mistakes
- `grep 4721` instead of matching `:4721 ` exactly, then killing every PID it shows.
- `kill -9` first: SIGTERM lets a service close connections and flush data; use -9 only when it doesn't stop.
- `pkill python3`: it stops every Python service on the box.

## Learn next
`lsof -nP -iTCP:PORT -sTCP:LISTEN` and `fuser -n tcp PORT` answer the same
question; `fuser -k -n tcp PORT` even kills the owner (careful). On systemd
hosts, `systemctl status PID` tells you which unit started a process, and
stopping the unit (not the PID) keeps it from coming back.
