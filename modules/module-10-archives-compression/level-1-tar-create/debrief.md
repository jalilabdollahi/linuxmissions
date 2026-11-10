# Ship the Site

## Why it works
tar stores each path the way it was named on the command line. `-C build/dist`
makes tar change into `build/dist` before reading `site`, so the members are
`site/index.html`, `site/.htaccess` and so on, and `tar -xzf` on the server
creates one `site/` folder. Naming the directory (not `site/*`) lets tar walk
the tree itself, so hidden files like `.htaccess` and `.well-known/` come along.

## Common mistakes
- `tar -czf release-2.3.tar.gz build/dist/site` keeps the whole path: the
  server would get `build/dist/site/`.
- `tar -czf ... site/*`: the shell expands `*` and skips dot files, so the
  redirect rules in `.htaccess` silently disappear from production.
- `cd build/dist/site && tar -czf release-2.3.tar.gz .` writes the archive into
  the folder it is reading. tar only warns "file changed as we read it", the
  members have no site/ prefix, and the half-written archive stays in the site
  where the next release picks it up.

## Learn next
`tar -tvzf` shows sizes, modes and owners of each member. When you build
releases, `--owner=0 --group=0` (GNU tar) keeps your local user name out of
the archive, and `--exclude` drops files you do not want to ship.
