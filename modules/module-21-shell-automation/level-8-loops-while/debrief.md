# Roll Call

## Why it works
`done < "$1"` connects the file to the standard input of the whole loop, and
every command inside inherits it. `read` takes one line, but ssh (and the
remote mock) forwards its stdin to the remote side, so it read everything
that was left. The next `read` hit end-of-file and the loop ended after one
host. `< /dev/null` (or `ssh -n`, or reading the file on fd 3 with
`read -u 3`) keeps the inventory for `read` alone.

The CMDB file had two more traps. Windows line endings leave a `\r` on the
end of each line: the host `web-01\r` does not resolve, and the `\r` lands in
status.txt. `${host%$'\r'}` removes it. And `read` returns "failure" on a final
line without a newline even though it set the variable, so
`|| [ -n "$host" ]` lets the loop handle that line too.

## Common mistakes
- Stripping `\r` after the empty-line check: a blank CRLF line is `\r` and
  becomes a host called "".
- `for host in $(cat inventory.txt)`: it seems to fix the loop, but splits on
  any whitespace and still keeps the `\r`.

## Learn next
`dos2unix FILE` or `tr -d '\r'` fixes line endings for a whole file.
`ssh -o BatchMode=yes -o ConnectTimeout=5` keeps a host check from hanging
on a password prompt or a dead host. Tools like `pssh` or `ansible -m ping`
run the same check in parallel.
