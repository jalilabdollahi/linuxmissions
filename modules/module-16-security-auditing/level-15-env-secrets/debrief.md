# The Password Everyone Can See

## Why it works
The command line of every process is world-readable (`ps`, `/proc/PID/cmdline`), so a secret
passed as an argument is exposed to every local user for as long as the process lives, and it often
ends up in logs and monitoring too. A path in an environment variable (`PASSWORD_FILE=...`) is harmless
because the secret itself sits in a file that only its owner can read (mode 600). The environment of a
process (`/proc/PID/environ`) is readable only by its owner and root, but it is still copied to every child
process, so secrets are better read from a file than exported.

## Common mistakes
- Moving the password from `--password=` to an `export DB_PASSWORD=...` in the same script: it is out of `ps` but still in the script and in the child processes' environment.
- `pkill -f worker` also kills the worker that was fine.
- Creating the password file with the default umask and fixing the mode afterwards.

## Next step
`systemd-creds`, Docker/Kubernetes secrets mounted as files and `LoadCredential=` in unit files all follow the
same idea: hand the process a path, not the secret. `ps -eww` shows command lines that `ps` would truncate.
