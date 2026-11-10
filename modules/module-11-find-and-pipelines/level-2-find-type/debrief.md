# After the Failed Deploy

## Why it works
find looks at each entry with `lstat`, so a symlink is reported as a link
(`-type l`) whatever it points to: a file, a directory such as `current`, or
nothing at all (`app.env.next`). `-empty` is true for empty directories *and*
zero-byte files, which is why it needs `-type d` next to it. A directory holding
only `.gitkeep` is not empty, and neither is `public/system`, whose only content
is the empty `print queue` folder.

## Common mistakes
- `find -L releases ...` or `find releases/current/ ...` follows links: you
  then search inside the target and the links themselves disappear.
- `find releases -empty` also lists `deploy.lock`, the `.gitkeep` files and
  `index.html.partial`.
- `ls -R | grep` cannot tell a link to a directory from a real directory.

## Learn next
`find releases -xtype l` (GNU) lists only *dangling* links, the ones whose target
is missing; on macOS use `find -L releases -type l`. `find releases -type d
-empty -delete` removes empty directories, deepest first, after you have the list.
