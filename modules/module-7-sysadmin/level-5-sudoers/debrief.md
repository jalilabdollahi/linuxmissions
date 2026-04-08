# Controlled Power

## What you practiced
Good sudo rules are as narrow as possible. Instead of granting broad root access, you can allow one command with one precise policy line.

## Commands to remember
```bash
visudo
/etc/sudoers.d/devuser
devuser ALL=(ALL) NOPASSWD: /usr/bin/systemctl
```
