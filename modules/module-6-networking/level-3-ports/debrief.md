# What's Listening?

## What you practiced
Socket listings tell you which services are waiting for connections. Reading the `LISTEN` rows is often the fastest way to inventory exposed ports.

## Commands to remember
```bash
ss -tln
netstat -tln
lsof -iTCP -sTCP:LISTEN
```
