# Fill the Template, Spare nginx

## Why it works
`envsubst` replaces `$VAR` and `${VAR}` with values from its environment. Called with a
quoted list such as `'$APP_HOST $APP_PORT'`, it replaces only those names and leaves
`$host`, `$remote_addr` and friends for nginx to evaluate at request time. The values must
be *exported*: a variable that only exists in your shell is invisible to the child process,
which is why `set -a` around `. ./deploy.env` (or `export APP_HOST=...`) is part of the recipe.

## Common mistakes
- Plain `envsubst < tmpl`: every nginx variable becomes an empty string and the config still "loads".
- Double quotes around the list: your shell expands the names first, and envsubst gets values.
- Forgetting to export: the app placeholders silently become empty.

## Next step
`envsubst --variables "$(cat nginx.conf.tmpl)"` lists every variable name a template
references, which helps when building the list.
