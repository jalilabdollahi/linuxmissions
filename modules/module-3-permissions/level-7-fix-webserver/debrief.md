# Web Server 403

## Why it works
To serve `webroot/pages/blog/launch day.html`, the web server user needs `x` on
**every** directory on the way (to pass through it) and `r` on the file. `755`
for directories and `644` for files gives exactly that and nothing more.
`find -type d` / `find -type f` lets you treat the two kinds separately, and
`-exec ... {} +` hands the names straight to chmod, so spaces and hidden files
are handled correctly.

## Common mistakes
- `chmod -R 644 webroot`: directories lose `x` and nobody, you included, can
  enter them any more.
- `chmod -R 755 webroot`: works for nginx, but makes every page executable.
- `chmod -R a=rX,u+w webroot` looks perfect (capital `X` = execute only for
  directories), but `X` also keeps `x` on files that already had it, so the
  777 `contact.html` would end up 755.

## Learn next
`namei -l webroot/pages/blog/launch\ day.html` (util-linux) prints owner and mode
of every directory along a path: the fastest way to find which one blocks a 403.
