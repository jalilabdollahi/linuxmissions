# Two Kinds of Dollar

## Why it works
Every `$` in a generated file belongs to one of two moments: when the
generator runs, or when the generated file is used. A quoted delimiter
(`<<'EOF'`) freezes the whole text; an unquoted one (`<<EOF`) expands
everything. Neither fits a file that needs both, so the heredoc stays
unquoted and the dollars that belong to later are escaped: `\$host` is
written as `$host` for nginx, `\$1` as `$1` for the health check. `$domain`
and `$port` stay unescaped and are filled in now.

## Common mistakes
- Escaping too much: `\$domain` writes `$domain` into the health check,
  where no such variable exists.
- Forgetting the `\` before `$path` in `url="...:$port\$path"`: the
  generator's own (empty) `$path` disappears silently. `bash -n` cannot catch
  that, only a diff against a known good file can.
- Checking arguments after `mkdir` and `cat >`: a bad call leaves half a
  vhost behind for nginx to load.

## Learn next
`<<-EOF` strips leading *tab* characters (not spaces) from each line and from
the closing delimiter, so heredocs can be indented inside functions and
loops. `envsubst '$DOMAIN $PORT' < vhost.tmpl` replaces only the variables
you name, a common way to keep templates as separate files. `nginx -t`
checks a generated config before a reload.
