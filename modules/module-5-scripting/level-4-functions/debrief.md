# DRY Deploy

## Why it works
A function is a named group of commands. When you call `deploy_service web`,
bash runs the body with `$1` set to `web`, just like a script receives its
arguments. `local name="$1"` keeps `name` inside the function, so it cannot
overwrite a `name` variable elsewhere in the script. Adding a fourth service is
now one line: `deploy_service billing`.

## Common mistakes
- Calling the function before it is defined. Bash reads the script top to
  bottom, so the definition must come first.
- Writing `deploy_service(api)`. Arguments are passed like command arguments:
  `deploy_service api`, never in parentheses.

## Learn next
A function's exit status is the status of its last command, or the value of
`return N`. Add `|| return 1` after `cp` and the caller can write
`deploy_service api || echo "api failed"`. For many services, loop:
`for svc in api web worker; do deploy_service "$svc"; done`.
