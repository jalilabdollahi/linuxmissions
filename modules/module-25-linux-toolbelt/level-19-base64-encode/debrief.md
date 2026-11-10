# Secrets Must Be Base64, Exactly

## Why it works
A Kubernetes Secret stores raw bytes as base64, and the decoded bytes are what
the pod receives. `head -n 1` returns the line with its newline, so the
newline must be dropped (`tr -d '\n'`, or `printf '%s'` instead of `echo`) or
the password would end in an invisible extra character and every login
would fail. GNU `base64` wraps its output at 76 characters, which would split
a YAML value over several lines; `-w0` keeps each value on one line. The
certificate and the PNG are encoded whole, as binary.

## Common mistakes
- `echo "$pw" | base64`: echo adds a newline that becomes part of the secret.
- Pasting the wrapped output into YAML: the value breaks at the first line end.
- Encoding the password file whole instead of its first line.

## Learn next
`kubectl create secret generic --from-file` does this encoding for you, and
`base64 -d` plus `cmp` is the quickest way to prove a value round-trips.
